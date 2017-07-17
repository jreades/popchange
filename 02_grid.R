#########################################
# Creates a grid of arbitrary resolution 
# for Scotland, Wales, and the GoR regions
# of England.
########################################
#rm(list = ls())
source('funcs.R')
source('config.R')
  
params = set.params(r)
target.crs = crs.gb
if (r=='Northern Ireland') {
  target.crs = crs.ni
}

cat("\n","======================\n","02:Grid (", params$display.nm,")\n")

# Region-Buffered shape
cat("  Simplifying and buffering region to control for edge effects.")
rb.shp <- buffer.region(params)

# Default
cat("  Working out extent of region and rounding to",g.anchor,"m.\n")
if (r=='Northern Ireland') { ## We want to emulate the actual grid
  box <- make.box(create.box(187000, 370000, 308000, 455000, proj=crs.ni), proj=crs.ni, a=1000)
} else { # Rest of UK
  box <- make.box(rb.shp)
}
  
# Resolution is the length of the grid on one side (if only one number then you get a square grid)
cat("  Creating raster grid with resolution of",g.resolution,"m.\n")
ra.r <- st_make_grid(box, cellsize=g.resolution, what="polygons", crs=CRS(paste('+init=epsg',target.crs,sep=":")))

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

cat("Done building grids.\n")