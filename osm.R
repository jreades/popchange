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
# It won't be perfect, but it should be more 
# robust than existing approaches which are
# based solely on smoothing and assignment 
# by centroid. I _do_ like the use of the
# NSPL to infer something about population
# density within the OA/ED/raster grid so I 
# will attempt to retain that.
#
# SETUP: this script expects the following dir
# structure -- the data directories are not 
# found in git because of the data volumes 
# associated with extracting and processing 
# OSM features.
#
# popchange/
#   no-sync/ # Don't manage content here with Git
#      OS/   # For Ordnance Survey data
#      OSM/  # For OSM data
#      land-polygons/ # Also OSM, but from different source
#      processed/     # Outputs from gridding process at national and regional levels
#
# FILTERING OUT 'UNLIKELY TO HAVE BEEN BUILT UP' AREAS -- 
# As outlined above... what I'm aiming for here is _excluding_ 
# those parts of Great Britain that are unlikely to have 
# been developed and then reverted to an undeveloped land use
# within the timeframe of a downloadable Census.
#
# The only widely available source of high-res *open* data on 
# such areas is OSM. The Ordnance Survey has some very nice 
# open data for Great Britain but that doesn't generalise well
# (especially for the locations of buildings). As well, their
# boundary line polygon data is not clipped to the high-water 
# mark, so that's another place we'll get 'development' creeping 
# into places it won't have happened. Meanwhile, the polyline
# high-water data can't be used to clip the boundary polygons.
# 
# Weeee, this is fun.
#
# So, on a conceptual level, what we do here is:
# 1. Get the high-water coastline of Britain from the Generalised, Clipped Country boundaries from the OS, or from OSM:
#    -> See http://geoportal.statistics.gov.uk/datasets/2039e084c4e8427981514b2a7fdd077e_0 (for 2014 boundaries)
#    -> See http://openstreetmapdata.com/data/land-polygons 
#       (it's not perfect -- the OS' generalised, clipped boundaries are better -- but it's totally open)
#
# 2. Use this to clip the administrative area boundaries:
#    -> See http://geoportal.statistics.gov.uk/datasets/f99b145881724e15a04a8a113544dfc5_2
#       (For England you can use the Regions generalised clipped data file to get only GOR:
#        Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp)
#    -> See https://www.ordnancesurvey.co.uk/business-and-government/products/boundary-line.html 
#       (in particular: district_borough_unitary_region.shp for getting smaller areas within countries)
#    -> I have done some additional clipping to remove the upper reaches of the Thames near London and similar
#
# 3. Generate land use data from OSM data (download as pbf file):
#    -> GeoFabrik nightly builds: http://download.geofabrik.de/europe/great-britain.html
#
# 4. Combine this land use data into a single file that suppresses 
#    areas from the later population distribution function.
########################################
# The strings here should match the Geofabrik OSM file name 
# (allowing for %>% ucfirst these are England, Scotland, Wales).
r.countries  <- c('England', 'Scotland', 'Wales')

# For England there is so much data that it makes sense 
# to break it down into regions. Even if our approach 
# below is a little inefficient (the bounding box for
# the South East actually includes all of London!) it 
# reduces the overall processing power required to 
# achieve the outputs and also theoretically enables
# it to be parallelised. We do not need to do this for
# Scotland and Wales, although if we dove below the GoR
# scale then we could use the district boundaries to 
# speed this up still further (although at the cost of 
# many more outputs to track and manage).
r.regions    <- c('London','North West','North East','Yorkshire and The Humber','East Midlands','West Midlands','East of England','South East','South West') # Applies to England only / NA for Scotland and Wales at this time

# We use the combination to generate an iterator.
r.iter       <- c(paste(r.countries[1],r.regions),r.countries[2:length(r.countries)])
r.buffer     <- 10000                      # Buffer to draw around region to filter (in metres)
osm.buffer   <- 5.0                        # Buffer to use around OSM features to help avoid splinters and holes (in metres)
osm.simplify <- 10.0                       # Simplify distance to use on OSM features to help speed up calculations (in metres)

library(rgdal)                             # R wrapper around GDAL/OGR
library(raster)                            # Useful functions for merging/aggregation
library(DBI)
library(sf)                                # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

# Where to find ogr2ogr -- on my system this is the OSX 
# location when installed from the fantastic KyngChaos web site
ogr.lib = '/Library/Frameworks/GDAL.framework/Programs/ogr2ogr'

# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
os.path = c(getwd(),'no-sync','OS')
osm.path = c(getwd(),'no-sync','OSM')
out.path = c(getwd(),'no-sync','processed')

# Set up the classes that we want to pull from the OSM PBF
# file. Each of these corresponds to a column configured 
# via the osmconf.ini file. In truth, the way OSM works 
# means that these columns are not strictly enforced (so,
# for instance, common can show up in leisure too). This 
# is why we merge them all and search for all of them in 
# all of the columns that we check.
#
# Note: it would be tempting to include some major features
# like national parks in this process; however, in the UK it
# is possible to have development within a national park (e.g.
# Aviemore within Cairngorms National Park; various
# within Peak District National Park) so I have deliberately
# left this land use out of the data pull.
osm.classes = new.env()
osm.classes$natural = c('wetland', 'water', 'heath', 'moor', 'wood', 'upland_fell', 'unimproved_grassland', 'mud', 'grass', 'grassland', 'fell', 'dune', 'coastline', 'beach', 'bay', 'common', 'scrub')
osm.classes$landuse = c('cemetery', 'airfield', 'allotments', 'brownfield', 'churchyard', 'farmland', 'farmyard',  'landfill', 'orchard', 'quarry', 'runway', 'vineyard', 'forest', 'marsh', 'meadow', 'park', 'reservoir', 'scrub', 'waterway', 'greenfield', 'village_green', 'playground') 
osm.classes$leisure = c('park', 'sports_field', 'water_park', 'recreation_ground', 'quad_bikes', 'nature_reserve', 'golf', 'miniature_golf', 'marina', 'golf_course', 'pitch', 'track') 
# These are amenity IS NOT NULL and these are NOT IN...
osm.classes$amenity = c('student_accomodation','retirement_home','nursing_home','hospice')
# These are NOT NULL...
osm.classes$not_null = c('aeroway') 
# This *could* be useful in theory but doesn't seem to add much value in practice
#osm.classes$other_tags = c('%Forest%', '%Common%', '%Heath%') # Based on the Other field: "designation"=>"Swinley Forest"

# Merge all classes to deal with inconsistency in tagging
# by OSM contributors
osm.classes$natural = unique(c(osm.classes$natural, osm.classes$landuse, osm.classes$leisure))
osm.classes$landuse = osm.classes$natural
osm.classes$leisure = osm.classes$natural

# Enables us to loop over all large regions
# in the dataset without having to load each
# individually
for (r in r.iter) {
  the.region <- .simpleCap(r)
  osm.region <- strsplit(r, " ")[[1]][1]
  if (osm.region==the.region) {
    r.filter <- FALSE
  } else {
    r.filter <- TRUE
  }
  cat(paste("\n","======================\n","Processing data for:",osm.region,"\n"))
  
  if (r.filter==FALSE) { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(paste(c(os.path, "CTRY_DEC_2011_GB_BGC.shp"), collapse="/"), stringsAsFactors=T)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$CTRY11NM==osm.region,]
    
  } else { # Filtering for regions
    r.filter.name <- sub("^[^ ]+ ","",r, perl=TRUE)
    cat(paste("  Processing internal region:", the.region,"\n")) 
    
    shp <- st_read(paste(c(os.path, "Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"), collapse="/"), stringsAsFactors=T)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Next the shapefile has to be converted to a dataframe for use in ggplot2
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- st_buffer(shp[shp$FILE_NAME==r.filter,], r.buffer, nQuadSegs=100)
    # Use this for filtering on GOR regions:
    r.shp <- st_buffer(shp[shp$rgn16nm==r.filter.name,], r.buffer, nQuadSegs=100)
  }
  # Useful for auditing, not necessary in production
  #st_write(r.shp, dsn=paste(c(os.path,'filterregion.shp'), collapse="/"), layer='filterregion', delete_dsn=TRUE)
  
  # Create bounding box from buffer -- 
  # we can then feed this into the OGR
  # query to subset the OSM data by region
  # without doing a more expensive check on
  # actual boundaries
  
  # What are the boundaries of the region?
  xmin = floor(st_bbox(r.shp)['xmin']/r.buffer)*r.buffer
  xmax = ceiling(st_bbox(r.shp)['xmax']/r.buffer)*r.buffer
  ymin = floor(st_bbox(r.shp)['ymin']/r.buffer)*r.buffer
  ymax = ceiling(st_bbox(r.shp)['ymax']/r.buffer)*r.buffer
  
  # Create an extent from these and then transform
  # to EPSG:4326 so that we can work out the coordinates
  # to use for clipping the OSM data
  e <- as(raster::extent(xmin, xmax, ymin, ymax), "SpatialPolygons")
  e.sf = st_as_sf(e)
  e.sf <- e.sf %>% st_set_crs(NA) %>% st_set_crs(27700)
  e.st = st_transform(e.sf, '+init=epsg:4326')
  #st_bbox(e.st)
  
  # For validation of bbox -- not needed in production
  # st_write(e.st, paste(c(os.path,'filterbounds.shp'),collapse="/"), layer='filterbounds', delete_dsn=TRUE)
  
  xmin = round(st_bbox(e.st)['xmin'], digits=4)
  xmax = round(st_bbox(e.st)['xmax'], digits=4)
  ymin = round(st_bbox(e.st)['ymin'], digits=4)
  ymax = round(st_bbox(e.st)['ymax'], digits=4)
  
  file.osm   = paste(c(osm.path, gsub('{region}',tolower(osm.region),'{region}-latest.osm.pbf', perl=TRUE)), collapse="/")
  file.clip  = paste(c(osm.path, gsub('{region}',the.region,'{region}-clip.shp', perl=TRUE)), collapse="/")
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
    if (r.filter==FALSE) {
      cat("Converting OSM multipolygon data to shapefile...\n")
      print(paste(c(ogr.lib, osm.noclip),collapse=" "))
      system2(ogr.lib, osm.noclip, wait=TRUE)
    } else {
      cat("Converting OSM multipolygon data to shapefile...\n")
      cat(paste("and clipping OSM data source using bbox extracted from",r.filter.name),"\n")
      print(paste(c(ogr.lib, osm.clip),collapse=" "))
      system2(ogr.lib, osm.clip, wait=TRUE)
    }
  } else {
    cat("Have already clipped OSM data to this region, skipping this operation...\n")
  }
  
  # Step 2: Select OSM classes and extract to reprojected shapefile
  for (k in ls(osm.classes)) {
    print(paste("Processing OSM class:", k))
    
    file.step1 = paste(c(out.path, gsub('{key}',k,gsub('{region}',the.region,'{region}-{key}-step1.shp', perl=TRUE), perl=TRUE)), collapse="/")
    file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',the.region,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
    
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
    
    cmd1 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', the.region, cmd1, perl=TRUE), perl=TRUE), perl=TRUE)
    cmd2 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', the.region, cmd2, perl=TRUE), perl=TRUE), perl=TRUE)
    
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
  file.merge = paste(c(out.path, gsub('{region}',the.region,'{region}-merge.shp', perl=TRUE)), collapse="/")
  cmd3 = c()
  for (k in ls(osm.classes)) {
    print(paste("Processing OSM class:", k))
    
    file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',the.region,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
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
  write(paste(cmd3, collapse=" "), file="merge.sh", append=TRUE)
}

# Step 4: Do the merge using a shell script to 
# prevent race and timeout conditions... seems 
# to be a weakness in RStudio/R in terms of
# impatience with system calls.
print(paste("Merge data script in",file.merge))
print(paste(c('/bin/sh',file.merge), collapse=" "))
system2('/bin/sh', file.merge, wait=TRUE)

# Step 5: Combine everything into a single filter

file.final = paste(c(out.path, gsub('{region}',the.region,'{region}-final.shp', perl=TRUE)), collapse="/")
final.sql  = gsub('{region}', the.region, '"SELECT \'Union\' AS \'Filter\', ST_Union(geometry) from \'{region}-merge\'"', perl=TRUE)
final.cmd  = c('-sql', final.sql, '-dialect','sqlite', file.final, file.merge, '-overwrite', '--config ogr_interleaved_reading yes')

# May also need to be run from command line -- 
# or may need a completely different approach
# as above using a shell script
print(paste(c(ogr.lib, final.cmd), collapse=" "))
system2(ogr.lib, final.cmd, wait=TRUE)

# ogr2ogr -f "ESRI Shapefile" -t_srs EPSG:27700 -s_srs EPSG:4326 -sql "select * from lines where waterway IN ('river','canal')" wales-rivers.shp ./OSM/wales-latest.osm.pbf overwrite --config ogr_interleaved_reading yes
