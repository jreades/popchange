######################################################
######################################################
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
#
# Note that this script is deliberately inefficient in
# that it is built using 4 loops that could be easily 
# collapsed into one monster. My feeling was that this 
# makes running/re-running parts of the script easier 
# in that you don't have to scroll through the loop 
# looking for where the part you want to re-run starts
# you can simply pick up from the stage in the process
# where you want to start processing the data. 
######################################################
######################################################

rm(list = ls()) # Clear the workspace

source('config.R')
source('funcs.R')

######################################################
######################################################
# Step #1. This loop deals with loading, converting, 
#          and clipping the raw OSM multipolygon data 
#          from the PBF file. Outputs a shapefile clipped
#          to the country or region and containing all
#          multipolygons in the OSM data file (there
#          in nothing in the polygons slot).
######################################################
######################################################
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing OSM data for:",params$display.nm,"\n")
  
  # Retrieve the outline of the country or English
  # region -- note that we buffer around English regions
  # and NI (because both have useful data falling on the 
  # 'other' side of the border) but not for Scotland or 
  # Wales because the OSM file cuts off at that point.
  cat("  Retrieving regional boundaries.\n")
  if (params$country.nm %in% c('England','Northern Ireland')) {
    rb.shp <- buffer.region(params)
  } else {
    rb.shp <- get.region(params)
  }
  
  # Useful for auditing, not necessary in production
  #st_write(rb.shp, dsn=get.path(paths$tmp,'filterregion.shp'), layer='filterregion', delete_dsn=TRUE, quiet=TRUE)
  
  #########
  # Step 1a: Subset the OSM file for a region (usually only done with England)
  
  # Derive a bounding box for the boundaries 
  # of the region? Note that these will be in
  # EPSG:27700 format (including NI since the 
  # ni-preprocessing step transforms that too).
  e = make.box(rb.shp)
  
  # Transform to EPSG:4326 so that we can work out 
  # the coordinates to use for clipping the OSM data
  e.st = st_transform(e, '+init=epsg:4326')
  
  # Work out the I/O path names
  file.osm   = get.path(paths$osm, get.file(t="{osm}-lastest.osm.pbf"))
  file.clip  = get.path(paths$osm, get.file(t="{file.nm}-clip.shp"))
  
  # And begin to build the clipping query to execute
  # using ogr2ogr.
  osm.clip   = c('-f "ESRI Shapefile"', '-sql "SELECT * FROM multipolygons"') 
  if (params$country.nm %in% c('England','Northern Ireland')) { 
    xmin     = st_bbox(e.st)['xmin']
    xmax     = st_bbox(e.st)['xmax']
    ymin     = st_bbox(e.st)['ymin']
    ymax     = st_bbox(e.st)['ymax']
    osm.clip = c(osm.clip, paste(c('-clipsrc',xmin,ymin,xmax,ymax)))
    cat("Bounding Box:",xmin,xmax,ymin,ymax,"\n")
  }
  osm.clip   = c(osm.clip, file.clip, file.osm, '-skipfailures', '-overwrite', '--config ogr_interleaved_reading yes')
  
  ########### Where we're at...
  cat("OSM Source file:",file.osm,"\n")
  cat("Clipping Destination file:",file.clip,"\n")
  cat("OGR Clipping Command:",osm.clip,"\n")
  
  # Just to prevent needless time-wasting we try
  # to avoid overwriting a file if it's already 
  # there. This would be fairly common if, for 
  # example, you were experimenting with different
  # classifications of the OSM data or just blindly
  # re-running the entire pipeline.
  if (!file.exists(file.clip)) {
    cat("Converting OSM multipolygon data to shapefile...","\n")
    cat("and clipping OSM data source where able","\n")
    cat(ogr.lib, osm.clip,"\n")
    system2(ogr.lib, osm.clip, wait=TRUE)
  } else {
    cat(paste(replicate(45, "="), collapse = ""), "\n")
    cat(paste(replicate(45, "="), collapse = ""), "\n")
    cat("Have already clipped OSM data for this region, skipping this operation...","\n")
    cat(paste(replicate(45, "="), collapse = ""), "\n")
    cat(paste(replicate(45, "="), collapse = ""), "\n")
  }
  rm(e,e.st,file.osm,file.clip,osm.clip,xmax,xmin,ymax,ymin)
}

######################################################
######################################################
# Step 2: Select OSM classes and extract to reprojected shapefile
#         Here we are extracting each of the use classes specified in the 
#         config.R file and grouping them into separate shapefiles for the 
#         time being. Everything will ultimately be merged back together 
#         but this lowers the memory profile and also permits ease of auditing
#         as well as dealing with the fact that each of these classes actually
#         requires a different retrieval query from the shapefile.
######################################################
######################################################
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing clipped data for:",params$display.nm,"\n")
  
  for (k in ls(osm.classes)) {
    cat("  Processing OSM class:",k,"\n")
    
    # Compose the I/O paths -- this could usefully
    # be made into a function eventually if I am 
    # going to sick with the "{...}" syntax instead
    # of just pasting it all together like a sane 
    # person.
    file.step1 = get.path(paths$tmp, get.file(t="{file.nm}-*-step1.shp",k))
    file.step2 = get.path(paths$tmp, get.file(t="{file.nm}-*-step2.shp",k))
    
    # And begin to compose both the extract and  
    # union queries.
    osm.extract = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:4326')
    osm.union = c('-dialect sqlite')
    
    # We look at the class to figure out which 
    # query to use -- amenity and 'not null' 
    # (which we use for airports) need a completely
    # different approach.
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
    
    osm.extract = c(osm.extract, file.step1, file.clip, '-overwrite', '-progress', '--config ogr_interleaved_reading yes')
    osm.union   = c(osm.union, file.step2, file.step1, '-overwrite', '-progress', '--config ogr_interleaved_reading yes')
    
    # And now compose the actual ogr2ogr commands
    cmd1 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', params$file.nm, osm.extract, perl=TRUE), perl=TRUE), perl=TRUE)
    cmd2 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', params$file.nm, osm.union, perl=TRUE), perl=TRUE), perl=TRUE)
    
    if (!file.exists(file.step1)) {
      cat("    Extracting and reprojecting data from clip file...\n")
      cat("    This may take between 1-10 minutes.\n")
      cat(ogr.lib, cmd1, "\n")
      system2(ogr.lib, cmd1, wait=TRUE)
    } else {
      cat("    ==== Step 1 file already exists. Skipping... ====\n")
    }
    
    if (!file.exists(file.step2)) {
      cat("    Simplifying and performing union on OSM classes...\n")
      cat("    This may take anywhere from 2-200 minutes.\n")
      cat(ogr.lib, cmd2, "\n")
      system2(ogr.lib, cmd2, wait=TRUE)
    } else {
      cat("    ==== Step 2 file already exists. Skipping... ====\n")
    }
  }
  rm(cmd1,cmd2,file.step1,file.step2,osm.extract,osm.union,val,k)
}

######################################################
######################################################
# Step 3: Merge the union-ed shapefiles into a single 
#         shapefile. I found that this process takes so long
#         that the R system2 function is assuming that the 
#         process is dead or something because I would start 
#         getting all sorts of errors. So, instead, what I've 
#         done is to create a bash script that can be fired off
#         by R (in case I'm wrong about this) or done manually
#         (assuming that I am). I should also point out that 
#         we create the foundation for the merge simply by 
#         copying the first shapefile in the list to the new 
#         location. I found that trying to create a brand new 
#         shapefile by merging was a patchy proposition *and*
#         slower to boot.
######################################################
######################################################

merge.sh = "merge.sh" # Feel free to change if you need to
file.remove(merge.sh) # If this isn't the first time

# For each region -- we'll append to the merge.sh script
# so that you can merge all of the data into region-specific
# shapefiles in one (looooong) process.
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================","\n","Setting up merge process for:",params$display.nm,"\n")
  
  
  file.merge = get.path(paths$osm, get.file(t="{file.nm}-merge.shp"))
  cmd3 = c()
  i    = 0
  for (k in ls(osm.classes)) {
    cat("  Processing OSM class:",k,"\n")
    
    file.step2 = get.path(paths$tmp, get.file(t="{file.nm}-*-step2.shp",k))
    #if (!file.exists(file.merge)) {
    if (i==0) {
      cat("     Will copy first shapefile to create merge base...\n") # More reliable than doing this via OGR for some strange reason
      cmd3 = c(cmd3, 'echo "   Copying base file:',k,'";')
      for (ext in c('.shp','.shx','.prj','.dbf')) {
        cmd3 = c(cmd3, '/bin/cp', gsub('.shp',ext,file.step2,perl=TRUE), gsub('.shp',ext,file.merge,perl=TRUE), ';')
      }
      i=1
    } else {
      cat("     Appending to shell script.\n")
      cmd3 = c(cmd3, 'echo "   Appending layer:',k,'";')
      cmd3 = c(cmd3, ogr.lib, file.merge, file.step2, '-append', '-update',';')
    }
  }
  # Useful debugging output
  #cat(cmd3, "\n")
  
  # Looks like this is best written to a 
  # shell script file and then executed 
  # from R rather than trying to make it a 
  # single system2() call from R.
  if (! file.exists(merge.sh)) {
    write("#!/bin/bash", file=merge.sh)
  }
  write(paste('echo "Starting merge: ',params$display.nm,'"',sep=""), file=merge.sh, append=TRUE)
  write(paste(cmd3, collapse=" "), file=merge.sh, append=TRUE)
  write(paste('echo "Merge complete: ',params$display.nm,'"',sep=""), file=merge.sh, append=TRUE)
  rm(cmd3,ext,file.merge,file.step2,i,k)
}

cat(paste(replicate(45, "="), collapse = ""), "\n")
cat(paste(replicate(45, "="), collapse = ""), "\n")
cat("You now need to run this in the Terminal:\n>\t",'/bin/sh',merge.sh,"\n")
#system2('/bin/sh', merge.sh, wait=TRUE)
#cat("Merge complete","\n")
cat(paste(replicate(45, "="), collapse = ""), "\n")
cat(paste(replicate(45, "="), collapse = ""), "\n")

rm(merge.sh)

######################################################
######################################################
# Step 4: Aggregate land uses into a couple of 
#         major categories and then intersect 
#         with the grid to calculate the usable
#         area within each.
######################################################
######################################################
cat("Starting integration with grid...","\n")
library(Hmisc)

script.sh = 'script.sh'
file.remove(script.sh)
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:", params$display.nm,"\n")
  
  #cat("  Loading grid with resolution",g.resolution,"m.","\n")
  grid.fn   = get.file(t="{file.nm}-{g.resolution}m-Grid.shp")
  grid.path = get.path(paths$grid, grid.fn)
  
  #cat("  Loading merged land use shapefile.","\n")
  merged.fn   = get.file(t="{file.nm}-merge.shp")
  merged.path = get.path(paths$osm, merged.fn)
  
  mrg <- st_read(merged.path, quiet=TRUE)
  mrg <- mrg %>% st_set_crs(NA) %>% st_set_crs(27700)
  
  rm(merged.fn, merged.path)
  
  # Now we need to process the land uses
  # separately based on whether they are
  # conceivably 'developlable' (e.g. farmyard)
  # or not (e.g. reservoir).
  lu  <- osm.classes.developable
  
  ###############
  # Developable land use classes first
  mrg.dev.fn   = get.file(t="{file.nm}-*-developable.shp",'merge')
  mrg.dev.path = get.path(paths$tmp,mrg.dev.fn)
  mrg.dev      = st_union(subset(mrg[mrg$UseClass %in% lu,]), by_feature=FALSE)
  st_write(mrg.dev, mrg.dev.path, quiet=TRUE, delete_dsn=TRUE)
  
  # Create a VRT file so that we can effectively 
  # refer to the layers that we need without needing
  # really long/escaped layer names.
  vrt.text <- sprintf('<OGRVRTDataSource>
  <OGRVRTLayer name="grid">
    <SrcDataSource>%s</SrcDataSource>
    <SrcLayer>%s</SrcLayer>
  </OGRVRTLayer>
  <OGRVRTLayer name="osm">
    <SrcDataSource>%s</SrcDataSource>
    <SrcLayer>%s</SrcLayer>
  </OGRVRTLayer>
</OGRVRTDataSource>',
  grid.path,
  gsub(".shp","",grid.fn,perl=TRUE),
  mrg.dev.path,
  gsub('.shp','',mrg.dev.fn,perl=TRUE)
  )
  write(vrt.text, file=get.path(paths$tmp,"Grid-Dev.vrt") )
  
  dev.out.path = get.path(paths$int, get.file(t="{file.nm}-{g.resolution}-Dev-Grid.shp"))
  
  
  cmd = c()
  
  cmd = c(cmd, 'echo "   Creating spatial index:',gsub(".shp","",grid.fn,perl=TRUE),'";',"\n")
  cmd = c(cmd, ogr.info, sprintf("-sql 'CREATE SPATIAL INDEX ON \"%s\"'",gsub(".shp","",grid.fn,perl=TRUE)), grid.path, ';',"\n")
  
  cmd = c(cmd, 'echo "   Creating spatial index:',gsub(".shp","",mrg.dev.fn,perl=TRUE),'";',"\n")
  cmd = c(cmd, ogr.info, sprintf("-sql 'CREATE SPATIAL INDEX ON \"%s\"'",gsub(".shp","",mrg.dev.fn,perl=TRUE)), mrg.dev.path, ';',"\n")
  
  cmd = c(cmd, 'echo "   Creating intersection and calculating overlapping area...";',"\n")
  cmd = c(cmd, 'echo "     Writing to', dev.out.path,'";',"\n")
  cmd = c(cmd, ogr.lib, '-dialect sqlite', "-sql 'SELECT t1.id, t1.geometry, area(st_intersection(t1.geometry,t2.geometry)) as \"d_over\", (\"d_over\"/area(t1.geometry))*100 as \"d_pct_over\" FROM grid t1, osm t2 WHERE st_intersects(t1.geometry,t2.geometry)'", '-f "ESRI Shapefile"', '-overwrite', '-progress', '--config ogr_interleaved_reading yes', dev.out.path, get.path(paths$tmp,"Grid-Dev.vrt"),';',"\n")
  
  ###############
  # Then non-developable ones (much larger)
  mrg.non = subset(mrg[mrg$UseClass %nin% lu,])
  
  mrg.ndev.fn   = gsub('{region}',params$file.nm,'{region}-merge-nondevelopable.shp', perl=TRUE)
  mrg.ndev.path = get.path(paths$tmp,mrg.ndev.fn)
  mrg.ndev      = st_union(subset(mrg[mrg$UseClass %nin% lu,]), by_feature=FALSE)
  st_write(mrg.ndev, mrg.ndev.path, quiet=TRUE, delete_dsn=TRUE)
  
  # Create a VRT file so that we can effectively 
  # refer to the layers that we need without needing
  # really long/escaped layer names.
  vrt.text <- sprintf('<OGRVRTDataSource>
  <OGRVRTLayer name="grid">
    <SrcDataSource>%s</SrcDataSource>
    <SrcLayer>%s</SrcLayer>
  </OGRVRTLayer>
  <OGRVRTLayer name="osm">
    <SrcDataSource>%s</SrcDataSource>
    <SrcLayer>%s</SrcLayer>
  </OGRVRTLayer>
</OGRVRTDataSource>',
  grid.path,
  gsub(".shp","",grid.fn,perl=TRUE),
  mrg.ndev.path,
  gsub('.shp','',mrg.ndev.fn,perl=TRUE)
  )
  write(vrt.text, file=get.path(paths$tmp,"Grid-Non-Dev.vrt") )
  
  ndev.out.path = get.path(paths$int, get.file(t="{file.nm}-{g.resolution}m-Non-Dev-Grid.shp"))
  
  # Already exists
  #cmd = c(cmd, 'echo "   Creating spatial index:',gsub(".shp","",grid.fn,perl=TRUE),'";')
  #cmd = c(cmd, ogr.info, sprintf("-sql 'CREATE SPATIAL INDEX ON \"%s\"'",gsub(".shp","",grid.fn,perl=TRUE)), grid.path, ';',"\n")
  
  cmd = c(cmd, 'echo "   Creating spatial index:',gsub(".shp","",mrg.ndev.fn,perl=TRUE),'";',"\n")
  cmd = c(cmd, ogr.info, sprintf("-sql 'CREATE SPATIAL INDEX ON \"%s\"'",gsub(".shp","",mrg.ndev.fn,perl=TRUE)), mrg.ndev.path, ';',"\n")
  
  cmd = c(cmd, 'echo "   Creating intersection and calculating overlapping area...";',"\n")
  cmd = c(cmd, 'echo "     Writing to', ndev.out.path,'";',"\n")
  cmd = c(cmd, ogr.lib, '-dialect sqlite', "-sql 'SELECT t1.id, t1.geometry, area(st_intersection(t1.geometry,t2.geometry)) as \"nd_over\", (\"nd_over\"/area(t1.geometry))*100 as \"nd_pct_over\" FROM grid t1, osm t2 WHERE st_intersects(t1.geometry,t2.geometry)'", '-f "ESRI Shapefile"', '-overwrite', '-progress', '--config ogr_interleaved_reading yes', ndev.out.path, get.path(paths$tmp,"Grid-Non-Dev.vrt"),';',"\n")
  
  write(paste(cmd, collapse=" "), file=script.sh, append=TRUE)
}

cat("Done linking OSM Data to grid.","\n")
