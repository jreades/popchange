rm(list = ls())
#########################################
# Creates a grid of arbitrary resolution 
# against either the entire UK (sort of)
# or a selected region from within Great 
# Britain.
#
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
# by centroid. I _do_ like the use of Code
# Point open to infer something about population
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
########################################

# The strings here should match the Geofabrik OSM file name 
# (allowing for %>% ucfirst these are England, Scotland, Wales).
r.countries  <- c('England', 'Scotland', 'Wales')

# For England there is so much data that it make sense 
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
g.resolution <- 1000                       # Grid resolution (in metres)
g.anchor     <- 10000                      # Round grid min/max x and y to nearest... (in metres)

library(viridis)
library(rgdal)                             # R wrapper around GDAL/OGR
library(raster)                            # Useful functions for merging/aggregation
library(DBI)
library(sf)                                # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

#library(devtools)                          # Needs to be on to use GitHub version of ggplot2
#dev_mode(on = T)
#install_github("hadley/ggplot2")           # Gain access to geom_sf?
#install_github("edzer/sfr")
#library(ggplot2)                           # for general plotting

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
# So what we aim to do here is:
# 1. Get the high-water coastline of Britain from OSM or the Generalised, Clipped Country boundaries from the OS:
#    -> See http://openstreetmapdata.com/data/land-polygons 
#       (it's not perfect -- the OS' generalised, clipped boundaries are better)
#    -> See http://geoportal.statistics.gov.uk/datasets/2039e084c4e8427981514b2a7fdd077e_0 (for 2014 boundaries)
#
# 2. If necessary, we can use this to clip the OS Boundary Line data to high-water coastline:
#    -> See https://www.ordnancesurvey.co.uk/business-and-government/products/boundary-line.html 
#       (in particular: district_borough_unitary_region.shp)
#    -> Saved output of this in paste(c(os.path,'UK-Regions-Clipped.shp'),collapse=" ")
#    -> Alternatively, use the Regions generalised clipped data file to get only GOR
#       (See http://geoportal.statistics.gov.uk/datasets/f99b145881724e15a04a8a113544dfc5_2)
#
# 3. Generate land use data from OSM data (download os pbf):
#    -> GeoFabrik nightly builds: http://download.geofabrik.de/europe/great-britain.html
#
# 4. Combine this land use data into a single file that suppresses 
#    areas from the population distribution function.
#
# 5. Generate a grid of arbitrary scale and cut out areas 
#    that can't have population

# Where to find ogr2ogr -- this is the OSX location when installed
# from the fantastic KyngChaos web site
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
osm.classes = new.env()
osm.classes$natural = c('wetland', 'water', 'heath', 'moor', 'wood', 'upland_fell', 'unimproved_grassland', 'mud', 'grass', 'grassland', 'fell', 'dune', 'coastline', 'beach', 'bay', 'common')
osm.classes$landuse = c('cemetery', 'airfield', 'allotments', 'brownfield', 'churchyard', 'farmland', 'farmyard',  'landfill', 'orchard', 'quarry', 'runway', 'vineyard', 'forest', 'marsh', 'meadow', 'park', 'reservoir', 'scrub', 'waterway', 'greenfield') 
osm.classes$leisure = c('park', 'sports_field', 'water_park', 'recreation_ground', 'quad_bikes', 'nature_reserve', 'golf', 'miniature_golf', 'marina', 'golf_course') 
osm.classes$not_null = c('aeroway') # IS NOT NULL -- these are a bit different
#osm.classes$other_tags = c('%Forest"', '%Common"%', '%Heath"%') # Other: "designation"=>"Swinley Forest"

# Merge all classes to deal with inconsistency in tagging
# by OSM contributors
osm.classes$natural = unique(c(osm.classes$natural, osm.classes$landuse, osm.classes$leisure))
osm.classes$landuse = osm.classes$natural
osm.classes$leisure = osm.classes$natural

# Step 1: Filter for the region based on boundary line with a buffer
# First read in the shapefile, using the path to the shapefile and the shapefile name minus the
# extension as arguments

# Very slow for some reason
# ggplot(shp) +
#   geom_sf(aes(fill=AREA)) +
#   scale_fill_viridis("Area") +
#   ggtitle("UK Districts") +
#   theme_bw()

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
  cat(paste("\n","Processing data for:",osm.region,"\n"))

  if (r.filter==FALSE) {
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(paste(c(os.path, "CTRY_DEC_2011_GB_BGC.shp"), collapse="/"), stringsAsFactors=T)
    
    # Check projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Extract country from shapefile:
    r.shp <- shp[shp$CTRY11NM==osm.region,]
    
  } else {
    r.filter.name <- sub("^[^ ]+ ", "", r, perl=TRUE)
    cat(paste("  Processing internal region:", the.region,"\n")) 
    
    shp <- st_read(paste(c(os.path, "Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"), collapse="/"), stringsAsFactors=T)
    
    # Check projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Next the shapefile has to be converted to a dataframe for use in ggplot2
    # Use this for filtering on districts: 
    #r.shp <- st_buffer(st_union(shp[shp$FILE_NAME==r.filter,]), r.buffer, nQuadSegs=100)
    # Use this for filtering on GOR regions:
    r.shp <- st_buffer(shp[shp$rgn16nm==r.filter.name,], r.buffer, nQuadSegs=100)
  }
  # Useful for auditing, not necessary in producting
  #st_write(r.shp, dsn=paste(c(os.path,'filterregion.shp'), collapse="/"), layer='filterregion', delete_dsn=TRUE)
  
  # Create bounding box from buffer -- 
  # we can then feed this into the OGR
  # query to subset the OSM data by region.
  
  # What are the boundaries of the region?
  xmin = floor(st_bbox(r.shp)['xmin']/g.anchor)*g.anchor
  xmax = ceiling(st_bbox(r.shp)['xmax']/g.anchor)*g.anchor
  ymin = floor(st_bbox(r.shp)['ymin']/g.anchor)*g.anchor
  ymax = ceiling(st_bbox(r.shp)['ymax']/g.anchor)*g.anchor
  
  # Create an extent from these and then transform
  # to EPSG:4326 so that we can work out the coordinates
  # to use for clipping the OSM data
  e <- as(raster::extent(xmin, xmax, ymin, ymax), "SpatialPolygons")
  e.sf = st_as_sf(e)
  e.sf <- e.sf %>% st_set_crs(NA) %>% st_set_crs(27700)
  e.st = st_transform(e.sf, '+init=epsg:4326')
  #st_bbox(e.st)
  
  # For validation of bbox -- if needed
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

  # Step 0: Subset the OSM file for a region (usually only done with England)
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
  
  # Step 1: Select OSM classes and extract to reprojected shapefile
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

  # And merge them into a single shapefile 
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

print(paste("Merged data in",file.merge))

# Before combining them all in a single multipolygon
# that we can use as a filter on the EDs and OAs
file.final = paste(c(out.path, gsub('{region}',the.region,'{region}-final.shp', perl=TRUE)), collapse="/")
final.sql  = gsub('{region}', the.region, '"SELECT \'Union\' AS \'Filter\', ST_Union(geometry) from \'{region}-merge\'"', perl=TRUE)
final.cmd  = c('-sql', final.sql, '-dialect','sqlite', file.final, file.merge, '-overwrite', '--config ogr_interleaved_reading yes')

print(paste(c(ogr.lib, final.cmd), collapse=" "))
# May need to be run from command line -- 
# or may need a completely different approach
system2(ogr.lib, final.cmd, wait=TRUE)

# ogr2ogr -f "ESRI Shapefile" -t_srs EPSG:27700 -s_srs EPSG:4326 -sql "select * from lines where waterway IN ('river','canal')" wales-rivers.shp ./OSM/wales-latest.osm.pbf overwrite --config ogr_interleaved_reading yes

# Now the shapefile can be plotted as either a geom_path or a geom_polygon.
# Paths handle clipping better. Polygons can be filled.
# You need the aesthetics long, lat, and group.
map <- ggplot() +
  geom_polygon(data = r.shp, 
            aes(x = long, y = lat, group = group),
            color = 'gray', fill = 'white', size = .2) + 
  labs(x="Easting", y="Northing", title=( if (is.null(r.filter)){"UK Map"}else{"Selected Region"} )) +
  coord_equal(ratio=1) # square plot to avoid the distortion
print(map) 

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

# We need to work out xmin and ymin such that we get a fairly consistent
# output no matter what the user specifies -- in other words, we don't 
# want grids starting at an Easting of 519,728 so it makes sense to round
# down (to be below and to the right) to the nearest... 10k?
g.positioning = 10000

r.ext = extent(r.shp)
x.min = floor(min(r.ext[1])/g.positioning)*g.positioning
y.min = floor(min(r.ext[3])/g.positioning)*g.positioning
x.max = ceiling(max(r.ext[2])/g.positioning)*g.positioning
y.max = ceiling(max(r.ext[4])/g.positioning)*g.positioning

# Resolution is the length of the grid on one side (if only one number then you get a square grid)
r <- raster(xmn=x.min, ymn=y.min, xmx=x.max,  ymx=y.max, crs = shp.prj, resolution=g.resolution)
r[] <- 1:ncell(r)
sp.r <- as(r, "SpatialPolygons")

# Aggregate the underlying region to deal with 
# areas that have multiple polygons
r.shp.unitary <- aggregate(r.shp, by = "FILE_NAME")

# Clip the grid to the regions polygons
clip <- gIntersection(r.shp.unitary, sp.r, byid=TRUE, drop_lower_td=TRUE)

# Knock out zones with no development
#erase(spdf1,  spdf2)

# And check our results
map <- ggplot() +
  geom_polygon(data=clip, 
            aes(x=long, y=lat, group=group),
            color='grey', size=0.4) +
  #geom_path(data=clip, 
  #          aes(x=long, y=lat, group=group),
  #          color='red', size=0.2) + 
  labs(x="Easting", y="Northing", title="Gridded Region") +
  coord_equal(ratio=1) # square plot to avoid the distortion
print(map)

