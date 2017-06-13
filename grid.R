rm(list = ls())
#########################################
# Creates a grid of arbitrary resolution 
# for Scotland, Wales, and the GoR regions
# of England.
########################################
source('config.R')
source('funcs.R')

library(sf)      # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:", params$country,"\n")
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  rb.shp <- buffer.region(r)
  
  cat("  Working out extent of region and rounding up/down to nearest ",g.anchor,"m\n")
  box <- make.box(rb.shp)
  
  # Resolution is the length of the grid on one side (if only one number then you get a square grid)
  cat("  Creating raster grid\n")
  ra.r <- st_make_grid(box, cellsize=g.resolution, what="polygons", crs=CRS('+init=epsg:27700'))
  
  # Tidy up
  rm(r.ext, x.min, y.min, x.max, y.max)
  
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
  is.within    <- st_intersects(ra.r, rb.shp) 
  sp.region    <- subset(ra.r, sapply(is.within, .flatten))
  
  # And write out the buffered grid ref
  st_write(sp.region, paste(c(grid.out.path,paste(params$label,'.shp',sep="")),collapse="/"), layer='bounds', delete_dsn=TRUE, quiet=TRUE)
  rm(is.within,ra.r,sp.region)
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