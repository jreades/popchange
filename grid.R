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
# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

# We need to work out xmin and ymin such that we get a fairly consistent
# output no matter what the user specifies -- in other words, we don't 
# want grids starting at an Easting of 519,728 so it makes sense to round
# down (to be below and to the right) to the nearest... 10k?
g.resolution <- 1000                       # Grid resolution (in metres)
g.anchor     <- 10000                      # Anchor grid min/max x and y at nearest... (in metres)

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

# Where to find ogr2ogr -- this is the OSX location when installed
# from the fantastic KyngChaos web site
ogr.lib = '/Library/Frameworks/GDAL.framework/Programs/ogr2ogr'

# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
os.path = c(getwd(),'no-sync','OS')
osm.path = c(getwd(),'no-sync','OSM')
out.path = c(getwd(),'no-sync','processed')

# Now the shapefile can be plotted as either a geom_path or a geom_polygon.
# Paths handle clipping better. Polygons can be filled.
# You need the aesthetics long, lat, and group.
# map <- ggplot() +
#   geom_polygon(data = r.shp, 
#             aes(x = long, y = lat, group = group),
#             color = 'gray', fill = 'white', size = .2) + 
#   labs(x="Easting", y="Northing", title=( if (is.null(r.filter)){"UK Map"}else{"Selected Region"} )) +
#   coord_equal(ratio=1) # square plot to avoid the distortion
# print(map) 

r.ext = extent(r.shp)
x.min = floor(min(r.ext[1])/g.anchor)*g.anchor
y.min = floor(min(r.ext[3])/g.anchor)*g.anchor
x.max = ceiling(max(r.ext[2])/g.anchor)*g.anchor
y.max = ceiling(max(r.ext[4])/g.anchor)*g.anchor

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