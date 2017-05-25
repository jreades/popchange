rm(list = ls())
#########################################
# Creates a grid of arbitrary resolution 
# against a selected region from within Great 
# Britain.
#
# The idea is to try to make a fully replicable
# process drawing solely on open data and a FOSS
# stack. This script should be run *after* osm.R
# since that is what creates the 'sieve' through
# which we'll filter out raster cells that can't
# have any people in them. This hsould improve the
# population allocation process later that makes 
# use of the nspl.R outputs.
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
r.countries  <- c('England', 'Scotland', 'Wales')
r.regions    <- c('London','North West','North East','Yorkshire and The Humber','East Midlands','West Midlands','East of England','South East','South West') # Applies to England only / NA for Scotland and Wales at this time
r.iter       <- c(paste(r.countries[1],r.regions),r.countries[2:length(r.countries)])
r.buffer     <- 10000                      # Buffer to draw around region to filter (in metres)

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

# We need to work out xmin and ymin such that we get a fairly consistent
# output no matter what the user specifies -- in other words, we don't 
# want grids starting at an Easting of 519,728 so it makes sense to round
# down (to be below and to the right) to the nearest... 10k?
g.resolution <- 750                        # Grid resolution (in metres)
g.anchor     <- 10000                      # Anchor grid min/max x and y at nearest... (in metres)

library(rgdal)                             # R wrapper around GDAL/OGR
library(raster)                            # Useful functions for merging/aggregation
library(DBI)
library(sf)                                # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

# Where to find ogr2ogr -- this is the OSX location when installed
# from the fantastic KyngChaos web site
ogr.lib = '/Library/Frameworks/GDAL.framework/Programs/ogr2ogr'

# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
os.path = c(getwd(),'no-sync','OS')
osm.path = c(getwd(),'no-sync','OSM')
out.path = c(getwd(),'no-sync','grid')

for (r in r.iter) {
  the.label <- .simpleCap(r)
  the.country <- strsplit(r, " ")[[1]][1]
  the.region <- paste(strsplit(r, " ")[[1]][-1], collapse=" ")
  
  cat(paste("\n","======================\n","Processing data for:", the.country,"\n"))
  
  if (length(the.region) == 0 | the.region=="") { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(paste(c(os.path, "CTRY_DEC_2011_GB_BGC.shp"), collapse="/"), stringsAsFactors=T)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$CTRY11NM==the.country,]
    
  } else { # Filtering for regions
    r.filter.name <- sub("^[^ ]+ ","",r, perl=TRUE)
    cat(paste("  Processing internal GoR region:", the.region,"\n")) 
    
    shp <- st_read(paste(c(os.path, "Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"), collapse="/"), stringsAsFactors=T)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Next the shapefile has to be converted to a dataframe for use in ggplot2
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- shp[shp$FILE_NAME==r.filter,]
    # Use this for filtering on GOR regions:
    r.shp <- shp[shp$rgn16nm==the.region,]
  }
  
  cat("  Working out extent of region and rounding up/down to nearest ",g.anchor,"m\n")

  r.ext = st_bbox(r.shp)
  x.min = floor(r.ext['xmin']/g.anchor)*g.anchor
  y.min = floor(r.ext['ymin']/g.anchor)*g.anchor
  x.max = ceiling(r.ext['xmax']/g.anchor)*g.anchor
  y.max = ceiling(r.ext['ymax']/g.anchor)*g.anchor

  # Resolution is the length of the grid on one side (if only one number then you get a square grid)
  r <- raster(xmn=x.min, ymn=y.min, xmx=x.max,  ymx=y.max, crs=CRS('+init=epsg:27700'), resolution=g.resolution)
  r[] <- 1:ncell(r)
  sp.r <- as(r, "SpatialPolygons")
  sp.r <- st_as_sf(sp.r) %>% st_set_crs(NA) %>% st_set_crs(27700)
  
  # Now clip it down to the region + a buffer distance...
  
  .flatten <- function(x) {
    if (length(x) == 0) { 
      FALSE
    } else { 
      TRUE
    }
  }
  # Save the output of st_within and then 
  # convert that to a logical vector using
  # sapply and the .flatten function
  cat("  Selecting cells falling within regional buffer.")
  is.within    <- st_intersects(sp.r, st_buffer(r.shp, r.buffer)) 
  sp.region    <- subset(sp.r, sapply(is.within, .flatten))
  
  st_write(sp.region, paste(c(out.path,'bounds.shp'),collapse="/"), layer='bounds', delete_dsn=TRUE)
  
  # Clip the grid to the regions polygons
  clip <- gIntersection(r.shp.unitary, sp.r, byid=TRUE, drop_lower_td=TRUE)
}



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