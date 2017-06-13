rm(list = ls())
#########################################
# Sets an attribute on the appropriate regional 
# grid to indicate whether a cell falls within 
# a configurable distance of a roadway.
#
# Note that this relies on data downloaded from 
# https://github.com/charlesroper/OSGB_Grids.
# You should save the 100km grid to the Roads directory.
########################################
source('config.R')
source('funcs.R')

library(sf)      # Replaces sp and does away with need for several older libs (sfr == dev; sf == production)

for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:", params$country,"\n")
  
  grd <- st_read(paste(c(grid.out.path,paste(params$label,'.shp',sep="")),collapse="/"), quiet=TRUE)
  grd <- grd %>% st_set_crs(NA) %>% st_set_crs(27700)
  
  if (r == 'Northern Ireland') {
    full.path = paste(c(roads.path,'OSNI_Open_Data__50k_Transport_Line','OSNI_Open_Data__50k_Transport_Line.shp'),collapse="/")
    rds <- st_read(full.path, quiet=TRUE)
    rds <- rds%>% st_set_crs(NA) %>% st_set_crs(29901)
    rds <- st_transform(rds, 27700)
  } else {
    # Now we need to work out which tiles we need -- we
    # do this by using the 100km reference downloaded
    # from GitHub. You can bin the rest.
    rb.shp    <- buffer.region(r)
    osgb.grid <- st_read( paste(c(roads.path,'OSGB_Grid_100km.shp'), collapse="/"), quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700)
    
    grid.intersects <- osgb.grid %>% st_intersects(rb.shp) %>% lengths()
    grid.tiles      <- sort(osgb.grid$TILE_NAME[ which(grid.intersects==1) ])
    rm(osgb.grid, grid.intersects)
    
    base.path = c(roads.path,'oproad_essh_gb','data')
    
    # Get the first tile from the list and 
    # extract only the roads falling within
    # the regional buffer
    rds <- st_read( paste(c(base.path,paste( grid.tiles[1],"RoadLink.shp",sep="_")), collapse="/"), quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700) 
    is.within <- rds.shp %>% st_intersects(rb.shp) %>% lengths()
    rds <- subset(rds, is.within==1)
    
    # Get any other tiles from the list and
    # extract only the roads falling within
    # the regional buffer
    for (g in grid.tiles[2:length(grid.tiles)]) {
      rds.shp <- st_read( paste(c(base.path,paste(g,"RoadLink.shp",sep="_")), collapse="/"), quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700)
      
      # Save the output of st_within and then 
      # convert that to a logical vector to
      # subset
      cat("  Selecting roads in ",g," falling within regional buffer.","\n")
      is.within <- rds.shp %>% st_intersects(rb.shp) %>% lengths()
      rds.shp   <- subset(rds.shp, is.within==1)
      
      rds <- rbind(rds, rds.shp)
      rm(rds.shp, is.within)
    }
    cat("Done assembling roads data for region...","\n")
  }
  
  cat("Buffering around roads.","\n")
  rds.buff <- st_buffer(st_simplify(rds, roads.simplify), roads.buffer)
  
  cat("Calculating intersection with grid.","\n")
  cell.intersects <- grd %>% st_intersects(rds.buff) %>% lengths()
  
  cat("Writing cell intersection values to shapefile.","\n")
  grd$nr_road = cell.intersects
  st_write(grd, 'test2.shp')
}