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

library(rgdal)   # R wrapper around GDAL/OGR
library(raster)  # Useful functions for merging/aggregation
library(DBI)
library(sf)      # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

# Enables us to loop over all large regions
# in the dataset without having to load each
# individually
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:",r,"\n")
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  rb.shp <- buffer.region(r)
  
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
  
  xmin = st_bbox(e.st)['xmin']
  xmax = st_bbox(e.st)['xmax']
  ymin = st_bbox(e.st)['ymin']
  ymax = st_bbox(e.st)['ymax']
  
  file.osm   = paste(c(osm.path, gsub('{region}',tolower(params$osm.country),'{region}-latest.osm.pbf', perl=TRUE)), collapse="/")
  file.clip  = paste(c(osm.path, gsub('{region}',params$region,'{region}-clip.shp', perl=TRUE)), collapse="/")
  osm.clip   = c('-f "ESRI Shapefile"', '-sql "SELECT * FROM multipolygons"', paste(c('-clipsrc',xmin,ymin,xmax,ymax)), file.clip, file.osm, '-skipfailures', '-overwrite', '--config ogr_interleaved_reading yes')
  osm.noclip = c('-f "ESRI Shapefile"', '-sql "SELECT * FROM multipolygons"', file.clip, file.osm, '-skipfailures', '-overwrite', '--config ogr_interleaved_reading yes')
  
  ########### Where we're at...
  cat(paste(c("Bounding Box:",xmin,xmax,ymin,ymax)))
  cat(file.osm,"\n")
  cat(file.clip,"\n")
  cat(osm.clip,"\n")  
  cat(osm.noclip,"\n") 
  
  # Step 1: Subset the OSM file for a region (usually only done with England)
  if (!file.exists(file.clip)) {
    if (r %in% c('Northern Ireland','Scotland')) {
      cat("Converting OSM multipolygon data to shapefile...\n")
      print(paste(c(ogr.lib, osm.noclip),collapse=" "))
      system2(ogr.lib, osm.noclip, wait=TRUE)
    } else {
      cat("Converting OSM multipolygon data to shapefile...\n")
      cat(paste("and clipping OSM data source using bbox for",r.filter.name),"\n")
      print(paste(c(ogr.lib, osm.clip),collapse=" "))
      system2(ogr.lib, osm.clip, wait=TRUE)
    }
  } else {
    cat("Have already clipped OSM data to this region, skipping this operation...\n")
  }
  
  # Step 2: Select OSM classes and extract to reprojected shapefile
  for (k in ls(osm.classes)) {
    print(paste("Processing OSM class:", k))
    
    # Missing what to do with amenity classes!
    # These are amenity IS NOT NULL and these are NOT IN... (i.e. all amenities except these ones are *included*)
    
    file.step1 = paste(c(out.path, gsub('{key}',k,gsub('{region}',params$region,'{region}-{key}-step1.shp', perl=TRUE), perl=TRUE)), collapse="/")
    file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',params$region,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
    
    osm.extract = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:4326', '-where "{key} IN ({val})"', file.step1, file.clip, '-overwrite', '--config ogr_interleaved_reading yes')
    osm.alternate.extract = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:4326', '-where "{val}"', file.step1, file.clip, '-overwrite', '--config ogr_interleaved_reading yes')
    
    osm.union = c('-dialect sqlite', gsub('{buffer}',osm.buffer,gsub('{simplify}',osm.simplify,'-sql "SELECT {key} AS UseClass, ST_Union(ST_Buffer(ST_Simplify(geometry,{simplify}),{buffer})) FROM \'{region}-{key}-step1\' GROUP BY {key}"',perl=TRUE),perl=TRUE), file.step2, file.step1, '-overwrite', '--config ogr_interleaved_reading yes') 
    osm.alternate.union = c('-dialect sqlite', gsub('{buffer}',osm.buffer,gsub('{simplify}',osm.simplify,'-sql "SELECT \'Other\' AS UseClass, ST_Union(ST_Buffer(ST_Simplify(geometry,{simplify}),{buffer})) FROM \'{region}-{key}-step1\'"',perl=TRUE),perl=TRUE), file.step2, file.step1, '-overwrite', '--config ogr_interleaved_reading yes') 
    
    if (k == 'not_null') {
      val = paste(paste("(", osm.classes[[k]], " IS NOT NULL", ")", sep=""), collapse=" OR ")
      cmd1 = osm.alternate.extract
      cmd2 = osm.alternate.union 
    } else {
      val = paste("'", paste(osm.classes[[k]], collapse="', '", sep=""), "'", collapse="", sep="")
      cmd1 = osm.extract
      cmd2 = osm.union 
    }
    
    cmd1 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', params$region, cmd1, perl=TRUE), perl=TRUE), perl=TRUE)
    cmd2 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', params$region, cmd2, perl=TRUE), perl=TRUE), perl=TRUE)
    
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
  
  # Step 3: Merge them into a single shapefile 
  file.merge = paste(c(out.path, gsub('{region}',params$region,'{region}-merge.shp', perl=TRUE)), collapse="/")
  cmd3 = c()
  for (k in ls(osm.classes)) {
    print(paste("Processing OSM class:", k))
    
    file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',params$region,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
    if (!file.exists(file.merge)) {
      print("     Creating 'merged' shapefile...")
      for (ext in c('.shp','.shx','.prj','.dbf')) {
        file.copy(gsub('.shp',ext,file.step2,perl=TRUE), gsub('.shp',ext,file.merge,perl=TRUE), overwrite=TRUE)
      }
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
  if (! file.exists("merge.sh")) {
    write("#!/bin/bash", file="merge.sh")
  }
  write(paste('echo "Starting merging: ',params$region,'"',sep=""), file="merge.sh", append=TRUE)
  write(paste(cmd3, collapse=" "), file="merge.sh", append=TRUE)
  write(paste('echo "Done merging: ',params$region,'"',sep=""), file="merge.sh", append=TRUE)
}

# Step 4: Do the merge using a shell script to 
# prevent race and timeout conditions... seems 
# to be a weakness in RStudio/R in terms of
# impatience with system calls.
cat("Merge data script in",file.merge,"\n")
cat(paste(c('/bin/sh',file.merge), collapse=" "),"\n")
system2('/bin/sh', file.merge, wait=TRUE)
cat("Merge complete","\n")

# Step 5: Aggregate land uses into a couple of 
#         major categories and then intersect 
#         with the grid
cat("Starting integration with grid","\n")
r.iter=c('Northern Ireland')
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:", params$region,"\n")
  
  grd <- st_read(paste(c(grid.out.path,paste(params$label,'.shp',sep="")),collapse="/"), quiet=TRUE)
  grd <- grd %>% st_set_crs(NA) %>% st_set_crs(27700)

  # Now we need to load and aggregate the 'merged'
  # file created above into the final classification.
  rb.shp    <- buffer.region(r)
  osgb.grid <- st_read( paste(c(roads.path,'OSGB_Grid_100km.shp'), collapse="/"), quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700)
  
  grid.intersects <- osgb.grid %>% st_intersects(rb.shp) %>% lengths()
  grid.tiles      <- sort(osgb.grid$TILE_NAME[ which(grid.intersects==1) ])
  rm(osgb.grid, grid.intersects)
  
  base.path = c(roads.path,'oproad_essh_gb','data')
  
  # Get the first tile from the list and 
  # extract only the roads falling within
  # the regional buffer
  rds <- st_read( paste(c(base.path,paste( grid.tiles[1],"RoadLink.shp",sep="_")), collapse="/"), quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700) 
  is.within <- rds.shp %>% st_intersects(rb.shp) %>% lengths()
  rds <- subset(rds, is.within==1)
  
  cat("   Buffering around roads.","\n")
  rds.buff <- st_buffer(st_simplify(rds, roads.simplify), roads.buffer)
  
  cat("   Calculating intersection with grid.","\n")
  cell.intersects <- grd %>% st_intersects(rds.buff) %>% lengths()
  
  cat("   Writing cell intersection values to shapefile.","\n")
  grd$nr_road = cell.intersects
  st_write(grd, paste( c(out.path, paste('Roads',r,'grid.shp', sep="-")), collapse="/"), quiet=TRUE, delete_dsn=TRUE)
}

cat("Done linking buffered roads to grid.","\n")

