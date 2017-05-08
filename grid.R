# Creates a grid of arbitrary resolution 
# against either the entire UK (sort of)
# of a selected region from within the UK.
r.filter     <- 'GREATER_LONDON_AUTHORITY' # Region to filter (see FILE_NAME field in shapefile)
g.resolution <- 1000                       # Grid resolution in metres

# Use the Boundary Line data set -- district_borough_unitary_region.shp

library(rgdal)     # R wrapper around GDAL/OGR
library(ggplot2)  # for general plotting
library(ggmap)    # for fortifying shapefiles
library(raster)
library(rgeos)
library(sp)
#library(osmar)

# FILTERING OUT UNLIKELY BUILT UP AREAS
# 1. Need the coatline of Britain at high-water:
#    Best free version I've found: http://openstreetmapdata.com/data/land-polygons 
#    -> See extracted UK_and_Ireland_Full.shp file for already subsetted data
#    Note: you can't do this with polylines from GB Boundary Line since they can't be joined effectively (or quickly)
# 2. Need land use data (download os pbf):
#    Best free version is the GeoFabrik nightly builds: http://download.geofabrik.de/europe/great-britain.html
# 3. Need to select polygons unlikely to be hosting (or to have hosted) development:
#    natural = wetland, water, heath, moor, wood, upland_fell, unimproved_grassland, mud, grass, grassland, fell, dune, coastline, beach, bay
#    landuse = forest, airfield, allotments, brownfield, churchyard, famland, farmyard, greenfield, landfill, marsh, meadow, orchard, park, quarry, reservoir, runway, scrub, vineyard, waterway, runway 
#    leisure = park, sports_field, water_park, recreation_ground, quad_bikes, nature_reserve, golf, miniature_golf, marina, golf_course, 
#    aeroway IS NOT NULL
# 4. Convert PBF data to Shapefile:
# ogr2ogr -f "ESRI Shapefile" -sql "select * from multipolygons where natural IN ('wetland', 'water', 'heath', 'moor', 'wood', 'upland_fell', 'unimproved_grassland', 'mud', 'grass', 'grassland', 'fell', 'dune', 'coastline', 'beach', 'bay')" wales-natural.shp wales-latest.osm.pbf --config ogr_interleaved_reading yes
# ogr2ogr -f "ESRI Shapefile" -sql "select * from multipolygons where landuse IN ('cemetery', 'forest', 'airfield', 'allotments', 'brownfield', 'churchyard', 'famland', 'farmyard', 'greenfield', 'landfill', 'marsh', 'meadow', 'orchard', 'park', 'quarry', 'reservoir', 'runway', 'scrub', 'vineyard', 'waterway', 'runway')" wales-landuse.shp wales-latest.osm.pbf --config ogr_interleaved_reading yes
# ogr2ogr -f "ESRI Shapefile" -sql "select * from multipolygons where leisure IN ('park', 'sports_field', 'water_park', 'recreation_ground', 'quad_bikes', 'nature_reserve', 'golf', 'miniature_golf', 'marina', 'golf_course')" wales-leisure.shp wales-latest.osm.pbf --config ogr_interleaved_reading yes
# ogr2ogr -f "ESRI Shapefile" -sql "select * from multipolygons where aeroway IS NOT NULL" wales-tags.shp wales-latest.osm.pbf --config ogr_interleaved_reading yes

coastline <- readOGR("./no-sync/land-polygons/", "UK_and_Ireland_Full-EPSG4326-5m")
landuse   <- readOGR("./no-sync/OSM/", "wales-landuse")
leisure   <- readOGR("./no-sync/OSM/", "wales-leisure")
natural   <- readOGR("./no-sync/OSM/", "wales-natural")
tags      <- readOGR("./no-sync/OSM/", "wales-tags")

u.landuse <- aggregate(landuse)
u.coastline <- aggregate(coastline)

tmp <- erase(u.coastline,  u.landuse)
plot(tmp)

# First read in the shapefile, using the path to the shapefile and the shapefile name minus the
# extension as arguments
shp <- readOGR("./no-sync/boundary-line/", "district_borough_unitary_region-25m")

# Check projection
shp.prj <- proj4string(shp)
if (length(grep("OSGB36",shp.prj))==0) {
  print("You should be using OSGB1936/BNG projections surely?")
}

if (is.null(r.filter)) {
  print("No filter on input shape.")
  print("Processing entire UK.")
  
  # Next the shapefile has to be converted to a dataframe for use in ggplot2
  r.shp <- shp
} else {
  print(paste("Filtering FILE_NAME attribute on",r.filter))
  
  # Next the shapefile has to be converted to a dataframe for use in ggplot2
  r.shp <- shp[shp$FILE_NAME==r.filter,]
}

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

