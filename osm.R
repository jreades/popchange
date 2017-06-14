rm(list = ls())
#########################################
# The idea is to try to make a fully replicable
# process drawing solely on open data and a FOSS
# stack. We work from the premise that certain 
# types of land use were highly unlikely to ever
# have _been_ built on in any meaningful way over
# the time period covered by digitised Censuses
# (Censi?) going back to the 1970s. We can use 
# those areas to influence our calculation of 
# population dispersion when we take our EDs and
# OAs and need to apportion them across more than
# one grid cell.
#
# So, on a conceptual level, what we do here is:
# 1. Get the high-water coastline of Britain from the 
#    Generalised, Clipped Country boundaries from the OS
# 2. Use this to clip the administrative area boundaries 
#    for the countries/regions to the high-water line
# 3. Extract land use data from OSM data
# 4. Combine this land use data into a single file that 
#    suppresses areas from the later population distribution 
#    function.
########################################
source('config.R')
source('funcs.R')

library(sf)      # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

# Enables us to loop over all large regions
# in the dataset without having to load each
# individually
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing OSM data for:",params$display.nm,"\n")
  
  # Region-Buffered shape
  cat("  Retrieving regional boundaries.\n")
  if (params$country.nm=='England') {
    rb.shp <- buffer.region(params)
  } else {
    rb.shp <- get.region(params)
  }
  
  # Useful for auditing, not necessary in production
  #st_write(rb.shp, dsn=paste(c(os.path,'filterregion.shp'), collapse="/"), layer='filterregion', delete_dsn=TRUE, quiet=TRUE)
  
  # Create bounding box from buffer -- 
  # we can then feed this into the OGR
  # query to subset the OSM data by region
  # without doing a more expensive check on
  # actual boundaries
  
  # What are the boundaries of the region?
  e = make.box(rb.shp)
  
  # Create an extent from these and then transform
  # to EPSG:4326 so that we can work out the coordinates
  # to use for clipping the OSM data
  e.st = st_transform(e, '+init=epsg:4326')
  #st_bbox(e.st)
  
  # For validation of bbox -- not needed in production
  # st_write(e.st, paste(c(os.path,'filterbounds.shp'),collapse="/"), layer='filterbounds', delete_dsn=TRUE, quiet=TRUE)
  
  file.osm   = paste(c(osm.path, gsub('{region}',params$osm,'{region}-latest.osm.pbf', perl=TRUE)), collapse="/")
  file.clip  = paste(c(osm.path, gsub('{region}',params$file.nm,'{region}-clip.shp', perl=TRUE)), collapse="/")
  
  osm.clip   = c('-f "ESRI Shapefile"', '-sql "SELECT * FROM multipolygons"') 
  if (params$country.nm == 'England') { 
    xmin     = st_bbox(e.st)['xmin']
    xmax     = st_bbox(e.st)['xmax']
    ymin     = st_bbox(e.st)['ymin']
    ymax     = st_bbox(e.st)['ymax']
    osm.clip = c(osm.clip, paste(c('-clipsrc',xmin,ymin,xmax,ymax)))
    cat(paste(c("Bounding Box:",xmin,xmax,ymin,ymax)))
  }
  osm.clip   = c(osm.clip, file.clip, file.osm, '-skipfailures', '-overwrite', '--config ogr_interleaved_reading yes')
  
  ########### Where we're at...
  cat("OSM Source file:",file.osm,"\n")
  cat("Clipping Destination file:",file.clip,"\n")
  cat("OGR Clipping Command:",osm.clip,"\n")
  
  # Step 1: Subset the OSM file for a region (usually only done with England)
  if (!file.exists(file.clip)) {
    cat("Converting OSM multipolygon data to shapefile...","\n")
    cat("and clipping OSM data source where able","\n")
    print(paste(c(ogr.lib, osm.clip),collapse=" "))
    system2(ogr.lib, osm.clip, wait=TRUE)
  } else {
    cat("Have already clipped OSM data to this region, skipping this operation...\n")
  }
  
  # Step 2: Select OSM classes and extract to reprojected shapefile
  for (k in ls(osm.classes)) {
    print(paste("Processing OSM class:", k))
    ###############
    # Missing what to do with amenity classes!
    # These are amenity IS NOT NULL and these are NOT IN... (i.e. all amenities except these ones are *included*)
    ###############
    file.step1 = paste(c(out.path, gsub('{key}',k,gsub('{region}',params$file.nm,'{region}-{key}-step1.shp', perl=TRUE), perl=TRUE)), collapse="/")
    file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',params$file.nm,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
    
    osm.extract = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:4326')
    osm.union = c('-dialect sqlite')
    
    if (k == 'not_null') {
      val = paste(paste("(", osm.classes[[k]], " IS NOT NULL", ")", sep=""), collapse=" OR ")
      osm.extract = c(osm.extract, gsub('{val}',val,'-where "{val}"',perl=TRUE))
      osm.union   = c(osm.union, gsub('{buffer}',osm.buffer,gsub('{simplify}',osm.simplify,'-sql "SELECT \'not null\' AS UseClass, ST_Union(ST_Buffer(ST_Simplify(geometry,{simplify}),{buffer})) FROM \'{region}-{key}-step1\'"',perl=TRUE),perl=TRUE))
      
    } else if (k == 'amenity') {
      val = paste("'", paste(osm.classes[[k]], collapse="', '", sep=""), "'", collapse="", sep="")
      osm.extract = c(osm.extract, gsub('{val}',val,'-where "{key} IS NOT NULL AND {key} NOT IN ({val})"',perl=TRUE))
      osm.union   = c(osm.union, gsub('{buffer}',osm.buffer,gsub('{simplify}',osm.simplify,'-sql "SELECT \'amenity\' AS UseClass, ST_Union(ST_Buffer(ST_Simplify(geometry,{simplify}),{buffer})) FROM \'{region}-{key}-step1\'"',perl=TRUE),perl=TRUE))
      
    } else {
      val = paste("'", paste(osm.classes[[k]], collapse="', '", sep=""), "'", collapse="", sep="")
      osm.extract = c(osm.extract, gsub('{val}',val,'-where "{key} IN ({val})"',perl=TRUE))
      osm.union   = c(osm.union, gsub('{buffer}',osm.buffer,gsub('{simplify}',osm.simplify,'-sql "SELECT {key} AS UseClass, ST_Union(ST_Buffer(ST_Simplify(geometry,{simplify}),{buffer})) FROM \'{region}-{key}-step1\' GROUP BY {key}"',perl=TRUE),perl=TRUE))
    }
    
    osm.extract = c(osm.extract, file.step1, file.clip, '-overwrite', '--config ogr_interleaved_reading yes')
    osm.union   = c(osm.union, file.step2, file.step1, '-overwrite', '--config ogr_interleaved_reading yes')
    
    cmd1 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', params$file.nm, osm.extract, perl=TRUE), perl=TRUE), perl=TRUE)
    cmd2 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', params$file.nm, osm.union, perl=TRUE), perl=TRUE), perl=TRUE)
    
    if (!file.exists(file.step1)) {
      cat("     Extracting and reprojecting data from clip file...\n")
      cat("     This may take between 1-10 minutes.\n")
      cat(paste(c(ogr.lib, cmd1), collapse=" "))
      system2(ogr.lib, cmd1, wait=TRUE)
    } else {
      cat("     Step 1 file already exists. Skipping.\n")
    }
    
    if (!file.exists(file.step2)) {
      cat("     Simplifying and performing union on OSM classes...\n")
      cat("     This may take anywhere from 2-200 minutes.\n")
      print(paste(c(ogr.lib, cmd2), collapse=" "))
      system2(ogr.lib, cmd2, wait=TRUE)
    } else {
      cat("     Step 2 file already exists. Skipping...\n")
    }
  }
}

# Step 3: Merge them into a single shapefile 
merge.sh = "merge.sh"
file.remove(merge.sh)
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================","\n","Setting up merge process for:",params$display.nm,"\n")
  
  
  file.merge = paste(c(out.path, gsub('{region}',params$file.nm,'{region}-merge.shp', perl=TRUE)), collapse="/")
  cmd3 = c()
  i    = 0
  for (k in ls(osm.classes)) {
    cat("  Processing OSM class:",k,"\n")
    
    file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',params$file.nm,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
    #if (!file.exists(file.merge)) {
    if (i==0) {
      cat("     Copying first shapefile to create merge base...\n")
      for (ext in c('.shp','.shx','.prj','.dbf')) {
        #file.copy(gsub('.shp',ext,file.step2,perl=TRUE), gsub('.shp',ext,file.merge,perl=TRUE), overwrite=TRUE)
        cmd3 = c(cmd3, '/bin/cp', gsub('.shp',ext,file.step2,perl=TRUE), gsub('.shp',ext,file.merge,perl=TRUE), ';')
      }
      i=1
    } else {
      cat("     Appending to 'merge shapefile' shell script.\n")
      #print(paste(c(ogr.lib, file.merge, file.step2, '-append', '-update;'), collapse=" "))
      #system2(ogr.lib, file.merge, file.step2, '-append', '-update', wait=TRUE)
      cmd3 = c(cmd3, ogr.lib, file.merge, file.step2, '-append', '-update',';')
    }
  }
  # Useful debugging output
  #print(paste(cmd3, collapse=" "))
  
  # Looks like this is best written to a 
  # shell script file and then executed 
  # from R rather than trying to make it a 
  # single system2() call from R.
  if (! file.exists(merge.sh)) {
    write("#!/bin/bash", file=merge.sh)
  }
  write(paste('echo "Starting merging: ',params$display.nm,'"',sep=""), file=merge.sh, append=TRUE)
  write(paste(cmd3, collapse=" "), file=merge.sh, append=TRUE)
  write(paste('echo "Done merging: ',params$display.nm,'"',sep=""), file=merge.sh, append=TRUE)
}

# Step 4: Do the merge using a shell script to 
# prevent race and timeout conditions... seems 
# to be a weakness in RStudio/R in terms of
# impatience with system calls.
cat("Merge data script in",merge.sh,"\n")
cat(paste(c('/bin/sh',merge.sh), collapse=" "),"\n")
system2('/bin/sh', merge.sh, wait=TRUE)
cat("Merge complete","\n")

# Step 5: Aggregate land uses into a couple of 
#         major categories and then intersect 
#         with the grid
cat("Starting integration with grid","\n")
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:", params$display.nm,"\n")
  
  cat("Loading grid with resolution",g.resolution,"m.\n")
  grid.fn = paste(c(grid.out.path,paste(params$file.nm,paste(g.resolution,"m",sep=""),'Grid.shp',sep="-")),collapse="/")
  
  grd <- st_read(grid.fn, quiet=TRUE)
  grd <- grd %>% st_set_crs(NA) %>% st_set_crs(27700)
  
  
  cat("   Writing cell intersection values to shapefile.","\n")
  osm.fn = paste( c(out.path, paste(params$file.nm,paste(g.resolution,'m',sep=""),'OSM','Grid.shp', sep="-")), collapse="/")
  st_write(grd, osm.fn, quiet=TRUE, delete_dsn=TRUE)
  rm(grd)
}

cat("Done linking OSM Data to grid.","\n")
