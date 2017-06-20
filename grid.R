#########################################
# Creates a grid of arbitrary resolution 
# for Scotland, Wales, and the GoR regions
# of England.
########################################
rm(list = ls())

source('config.R')
source('funcs.R')

library(sf)      # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:",params$display.nm,".\n")
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  rb.shp <- buffer.region(params)
  
  cat("  Working out extent of region and rounding to",g.anchor,"m.\n")
  box <- make.box(rb.shp)
  
  # Resolution is the length of the grid on one side (if only one number then you get a square grid)
  cat("  Creating raster grid with resolution of",g.resolution,"m.\n")
  ra.r <- st_make_grid(box, cellsize=g.resolution, what="polygons", crs=CRS('+init=epsg:27700'))
  
  # Save the output of st_within and then 
  # convert that to a logical vector using
  # sapply and the .flatten function
  cat("  Selecting cells falling within regional buffer.\n")
  grid.intersects <- ra.r %>% st_intersects(rb.shp) %>% lengths()
  grid.tiles      <- subset(ra.r, grid.intersects==1)
  
  # And write out the buffered grid ref
  grid.fn = get.path(paths$grid, get.file(t="{file.nm}-{g.resolution}m-Grid.shp"))
  cat("Writing grid file: ",grid.fn,"\n")
  
  st_write(grid.tiles, grid.fn, layer='bounds', delete_dsn=TRUE, quiet=TRUE)
  rm(grid.intersects,grid.tiles,ra.r,grid.fn)
}

cat("Done building grids.\n")