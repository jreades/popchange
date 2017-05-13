rm(list = ls())

# Creates a grid of arbitrary resolution 
# against either the entire UK (sort of)
# of a selected region from within the UK.
r.filter     <- 'GREATER_LONDON_AUTHORITY' # Region to filter (see FILE_NAME field in Boundary Line data)
osm.region   <- 'england'
osm.buffer   <- 5.0
osm.simplify <- 10
g.resolution <- 1000                       # Grid resolution in metres

library(rgdal)    # R wrapper around GDAL/OGR
library(ggplot2)  # for general plotting
library(ggmap)    # for fortifying shapefiles
library(raster)   # Useful functions for merging/aggregation
library(rgeos)
library(sp)
#library(osmar)

# Create bounding box from Shapefile -- 
# we can then feed this into the OGR
# query to subset the OSM data by region.
e <- as(raster::extent(500000, 140000, 550000, 200000), "SpatialPolygons")
proj4string(e) = CRS("+init=epsg:27700")
t = spTransform(e, CRS("+init=epsg:4326"))
extent(t)
# SUPPORTS: ogr2ogr -t_srs EPSG:27700 -s_srs EPSG:4326 -sql "select * from multipolygons where natural IN ('wetland', 'water', 'heath', 'moor', 'wood', 'upland_fell', 'unimproved_grassland', 'mud', 'grass', 'grassland', 'fell', 'dune', 'coastline', 'beach', 'bay')" -spat -6.044675 51.63855 -0.4446272 54.83485 -f "ESRI Shapefile" test.shp ./OSM/england-latest.osm.pbf -overwrite --config ogr_interleaved_reading yes
# ogr2ogr -t_srs EPSG:27700 -s_srs EPSG:4326 -spat 500000 140000 505000 160000 -spat_srs EPSG:27700 -f "ESRI Shapefile" test ./OSM/england-latest.osm.pbf -overwrite --config ogr_interleaved_reading yes SHPT=POLYGON

# FILTERING OUT UNLIKELY TO HAVE BEEN BUILT UP AREAS -- 
# What I'm aiming for here is _excluding_ those parts of
# Great Britain that are unlikely to have _ever_ been 
# developed within the timeframe of a downloadable Census.
#
# The only widely available source of high-res open data on 
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
# 1. Get the high-water coastline of Britain from OSM:
#    -> See http://openstreetmapdata.com/data/land-polygons 
#
# 2. Use this to clip the OS Boundary Line data to high-water coastline:
#    -> See https://www.ordnancesurvey.co.uk/business-and-government/products/boundary-line.html 
#       (in particular: district_borough_unitary_region.shp)
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
# via the osmconf.ini file.
osm.classes = new.env()
osm.classes$natural = c('wetland', 'water', 'heath', 'moor', 'wood', 'upland_fell', 'unimproved_grassland', 'mud', 'grass', 'grassland', 'fell', 'dune', 'coastline', 'beach', 'bay')
osm.classes$landuse = c('cemetery', 'airfield', 'allotments', 'brownfield', 'churchyard', 'farmland', 'farmyard',  'landfill', 'orchard', 'quarry', 'runway', 'vineyard', 'forest', 'marsh', 'meadow', 'park', 'reservoir', 'scrub', 'waterway', 'greenfield') 
osm.classes$leisure = c('park', 'sports_field', 'water_park', 'recreation_ground', 'quad_bikes', 'nature_reserve', 'golf', 'miniature_golf', 'marina', 'golf_course') 
osm.classes$not_null = c('aeroway') # IS NOT NULL -- these are a bit different

# Step 1: Filter for the region based on boundary line with a buffer
# First read in the shapefile, using the path to the shapefile and the shapefile name minus the
# extension as arguments
shp <- readOGR(paste(os.path, collapse="/"), "district_borough_unitary_region-25m")

# Check projection
shp.prj <- proj4string(shp)
if (length(grep("OSGB36",shp.prj))==0) {
  print("You should be using OSGB1936/BNG projections surely?")
}

if (is.null(r.filter)) {
  print("No filter on input shape.")
  print("Processing entire zone.")
  
  # Next the shapefile has to be converted to a dataframe for use in ggplot2
  r.shp <- shp
} else {
  print(paste("Filtering FILE_NAME attribute on",r.filter))
  
  # Next the shapefile has to be converted to a dataframe for use in ggplot2
  r.shp <- shp[shp$FILE_NAME==r.filter,]
}

# Simple data frame to allow aggregation
lu <- c('Filter')
lu <- as.data.frame(lu)
colnames(lu) <- "filter"  # your data will probably have more than 1 row!

u.shp <- SpatialPolygonsDataFrame(gBuffer(aggregate(r.shp, byid=TRUE), byid=TRUE, width=20000, quadsegs=100), lu)
writeOGR(u.shp, dsn=paste(os.path,collapse="/"), layer='filterregion', driver="ESRI Shapefile", overwrite_layer=TRUE)

# Step 1: Select OSM classes and extract to reprojected shapefile
for (k in ls(osm.classes)) {
  print(paste("Processing OSM class:", k))
  
  file.osm   = paste(c(osm.path, gsub('{region}',osm.region,'{region}-latest.osm.pbf', perl=TRUE)), collapse="/")
  file.step1 = paste(c(out.path, gsub('{key}',k,gsub('{region}',osm.region,'{region}-{key}-step1.shp', perl=TRUE), perl=TRUE)), collapse="/")
  file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',osm.region,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
  
  osm.extract = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:4326', '-sql "select * from multipolygons where {key} IN ({val})"', file.step1, file.osm, '-overwrite', '--config ogr_interleaved_reading yes')
  osm.alternate.extract = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:4326', '-sql "select * from multipolygons where {val}"', file.step1, file.osm, '-overwrite', '--config ogr_interleaved_reading yes')
  
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
  
  cmd1 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', osm.region, cmd1, perl=TRUE), perl=TRUE), perl=TRUE)
  cmd2 = gsub('{val}', val, gsub('{key}', k, gsub('{region}', osm.region, cmd2, perl=TRUE), perl=TRUE), perl=TRUE)
  
  if (!file.exists(file.step1)) {
    print("     Extracting and reprojecting data from PBF file...")
    print("     This may take between 1-10 minutes.")
    #print(cmd1)
    system2(c(ogr.lib, cmd1), wait=TRUE)
  } else {
    print("     Step 1 file already exists. Skipping.")
  }
  
  if (!file.exists(file.step2)) {
    print("     Simplifying and performing union on OSM classes...")
    print("     This may take anywhere from 5-45 minutes.")
    #print(cmd2)
    system2(c(ogr.lib, cmd2), wait=TRUE)
  } else {
    print("     Step 2 file already exists. Skipping.")
  }
}

# And merge them into a single shapefile
file.merge = paste(c(out.path, gsub('{region}',osm.region,'{region}-merge.shp', perl=TRUE)), collapse="/")
for (k in ls(osm.classes)) {
  print(paste("Processing OSM class:", k))
  
  # Defunct Approach:
  # This seems sloooooow compared to just duplicating
  # the file via `cp`, but the recommended approach using
  # ogr2ogr (which should be an intermediately useful 
  # method) seems to break all the time!
  #sql.query  = gsub('{key}',k,gsub('{region}',osm.region,'-sql "SELECT * FROM \'{region}-{key}-step2\'"', perl=TRUE), perl=TRUE)
  #print(paste(ogr.lib, file.merge, file.step2, '-dialect sqlite', sql.query, '-f "ESRI Shapefile"'))
  #system2(ogr.lib, file.merge, file.step2,'-dialect sqlite', sql.query, '-f "ESRI Shapefile"')
  
  file.step2 = paste(c(out.path, gsub('{key}',k,gsub('{region}',osm.region,'{region}-{key}-step2.shp', perl=TRUE), perl=TRUE)), collapse="/")
  if (!file.exists(file.merge)) {
    print("     Creating 'merged' shapefile...")
    for (ext in c('.shp','.shx','.prj','.dbf')) {
      file.copy(gsub('.shp',ext,file.step2,perl=TRUE), gsub('.shp',ext,file.merge,perl=TRUE), overwrite=TRUE)
    }
  } else {
    print("     Appending to 'merged' shapefile")
    system2(c(ogr.lib, file.merge, file.step2, '-append', '-update'), wait=TRUE)
  }
}

# Before combining them all in a single multipolygon
# that we can use as a filter on the EDs and OAs
file.final = paste(c(out.path, gsub('{region}',osm.region,'{region}-final.shp', perl=TRUE)), collapse="/")
final.sql  = gsub('{region}', osm.region, '"SELECT \'Union\' AS \'Filter\', ST_Union(geometry) from \'{region}-merge\'"', perl=TRUE)
final.cmd  = c('-sql', final.sql, '-dialect','sqlite', file.final, file.merge, '-overwrite', '--config ogr_interleaved_reading yes')

print(paste(c(ogr.lib, final.cmd), collapse=" "))
# May need to be run from command line -- 
# or may need a completely different approach
#system2(ogr.lib, final.cmd)

# ogr2ogr -f "ESRI Shapefile" -t_srs EPSG:27700 -s_srs EPSG:4326 -sql "select * from lines where waterway IN ('river','canal')" wales-rivers.shp ./OSM/wales-latest.osm.pbf overwrite --config ogr_interleaved_reading yes

coastline <- readOGR("./no-sync/land-polygons/", "UK_and_Ireland_Full-5m")
u.coastline <- aggregate(coastline)

tmp <- erase(u.coastline,  u.landuse)
plot(tmp)

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

