rm(list = ls())
##################
##################
# Convert to sf_make_grid
##################
##################
#########################################
# Creates a grid of arbitrary resolution 
# for Scotland, Wales, and the GoR regions
# of England.
########################################
source('config.R')

# Temporary mod
g.resolution=100
g.anchor=2000
r.buffer=5000

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

library(rgdal)   # R wrapper around GDAL/OGR
library(raster)  # Useful functions for merging/aggregation
library(DBI)     # Required by sf
library(sf)      # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

for (r in r.iter) {
  the.label <- .simpleCap(r)
  the.country <- strsplit(r, " ")[[1]][1]
  the.region <- paste(strsplit(r, " ")[[1]][-1], collapse=" ")
  
  if (r=='Northern Ireland') {
    the.country <- 'Northern-Ireland'
    the.region  <- ""
  }
  
  cat("\n","======================\n","Processing data for:", the.country,"\n")
  
  if (length(the.region) == 0 | the.region=="") { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(paste(c(os.path, "CTRY_DEC_2011_UK_BGC.shp"), collapse="/"), stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$CTRY11NM==the.country,]
    
  } else { # Filtering for regions
    r.filter.name <- sub("^[^ ]+ ","",r, perl=TRUE)
    cat("  Processing internal GoR region:", the.region,"\n") 
    
    shp <- st_read(paste(c(os.path, "Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"), collapse="/"), stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Next the shapefile has to be converted to a dataframe for use in ggplot2
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- shp[shp$FILE_NAME==r.filter,]
    # Use this for filtering on GOR regions:
    r.shp <- shp[shp$rgn16nm==the.region,]
  }
  rm(shp)
  
  # Simplify and buffer
  cat(" Simplifying and buffering region to speed up next stages\n")
  r.shp <- st_buffer(st_simplify(r.shp, r.simplify), r.buffer)
  
  cat("  Working out extent of region and rounding up/down to nearest ",g.anchor,"m\n")

  r.ext = st_bbox(r.shp)
  x.min = floor(r.ext['xmin']/g.anchor)*g.anchor
  y.min = floor(r.ext['ymin']/g.anchor)*g.anchor
  x.max = ceiling(r.ext['xmax']/g.anchor)*g.anchor
  y.max = ceiling(r.ext['ymax']/g.anchor)*g.anchor
  
  ################
  ################
  # Convert to sf_make_grid
  ################
  ################
  
  # Resolution is the length of the grid on one side (if only one number then you get a square grid)
  cat("  Creating raster grid\n")
  ra.r <- raster(xmn=x.min, ymn=y.min, xmx=x.max,  ymx=y.max, crs=CRS('+init=epsg:27700'), resolution=g.resolution)
  ra.r[] <- 1:ncell(r)
  
  # We need this to pass in an extent to crop
  # and a sp data frame to mask
  r.sp <- as(r.shp, "Spatial")
  
  # The crop function shouldn't make any difference
  # as we've already used the extent to creat the 
  # raster, but the mask should reduce the number of
  # polygons generated and, consequently, the processing
  # time. At the limit it may replace the st_within test
  # below.
  ra.r <- mask(crop(ra.r, extent(r.sp)), r.sp)
  
  # Tidy up
  rm(r.sp, r.ext, x.min, y.min, x.max, y.max)
  
  # Convert the raster to polygons so that we are working
  # directly with a grid and reproject it as a sf object
  sp.r <- as(ra.r, "SpatialPolygons")
  sp.r <- st_as_sf(sp.r) %>% st_set_crs(NA) %>% st_set_crs(27700)
  
  # Now clip it down to the region + a buffer distance...
  # Need a function to extract usable info from the 
  # st_intersects call.
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
  is.within    <- st_intersects(sp.r, r.shp) 
  sp.region    <- subset(sp.r, sapply(is.within, .flatten))
  
  # And write out the buffered grid ref
  st_write(sp.region, paste(c(grid.out.path,paste(the.label,'.shp',sep="")),collapse="/"), layer='bounds', delete_dsn=TRUE, quiet=TRUE)
}

# Knock out zones with no development
#erase(spdf1,  spdf2)

# And check our results
# map <- ggplot() +
#   geom_polygon(data=clip, 
#                aes(x=long, y=lat, group=group),
#                color='grey', size=0.4) +
#   #geom_path(data=clip, 
#   #          aes(x=long, y=lat, group=group),
#   #          color='red', size=0.2) + 
#   labs(x="Easting", y="Northing", title="Gridded Region") +
#   coord_equal(ratio=1) # square plot to avoid the distortion
# print(map)