# Creates a UK-sized grid of arbitrary resolution

# Use the Boundary Line data set -- district_borough_unitary_region.shp

library(rgdal)     # R wrapper around GDAL/OGR
library(ggplot2)  # for general plotting
library(ggmap)    # for fortifying shapefiles
library(raster)
library(sp)

# First read in the shapefile, using the path to the shapefile and the shapefile name minus the
# extension as arguments
shp <- readOGR("./no-sync/boundary-line/", "district_borough_unitary_region-25m")

# Check projection
prj <- proj4string(shp)
if (length(grep("OSGB36",prj))==0) {
  print("You should be using OSGB1936/BNG projections surely?")
}

# Next the shapefile has to be converted to a dataframe for use in ggplot2
shp_df <- fortify(shp)

# Now the shapefile can be plotted as either a geom_path or a geom_polygon.
# Paths handle clipping better. Polygons can be filled.
# You need the aesthetics long, lat, and group.
map <- ggplot() +
  geom_path(data = shp_df, 
            aes(x = long, y = lat, group = group),
            color = 'gray', fill = 'white', size = .2) +
  geom_path(data = r_df, 
            aes(x=x, y=y, color='red'))

print(map) 

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r
#r <- raster(extent(matrix( c(0, 0, max(shp_df$long),  max(shp_df$lat)), nrow=2)), nrow=10, ncol=10, crs = prj)   
# Resolution is the length of the grid on one side (if only one number then you get a square grid)
r <- raster(xmn=0, ymn=0, xmx=max(shp_df$long),  ymx=max(shp_df$lat), crs = prj, resolution=100000)
r[] <- 1:ncell(r)

sp.r <- as(r, "SpatialPolygonsDataFrame")
r_df <- fortify(sp.r)

map <- ggplot() +
  geom_path(data = r_df, 
            aes(x = long, y = lat, group = group),
            color = 'gray', fill = 'white', size = .2)
print(map)

map <- ggplot() +
  geom_path(data = shp_df, 
            aes(x = long, y = lat, group = group),
            color = 'gray', fill = 'white', size = .2) +
  geom_path(data = r_df, 
            aes(x = long, y = lat, group = group),
            color = 'red', fill = 'white', size = .2)
print(map)