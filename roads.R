#########################################
# Sets an attribute on the appropriate regional 
# grid to indicate whether a cell falls within 
# a configurable distance of a roadway.
#
# Note that this relies on data downloaded from 
# https://github.com/charlesroper/OSGB_Grids.
# You should save the 100km grid to the Roads directory.
########################################
rm(list = ls())
source('funcs.R')
source('config.R')

library(Hmisc) # For %nin%

# Notice that these match the targets below --
# the buffer sizes are set in the config file.
road.classes = c('Motorway','Main','Local') 

# These map the OSNI and OS classes on to the
# 'target' columns that we will use to create
# the weights.
openroads.map = new.env()
openroads.map$motorway.src    = c("Motorway")
openroads.map$motorway.target = 'Motorway'
openroads.map$main.src        = c("A Road", "B Road")
openroads.map$main.target     = 'Main'
openroads.map$local.src       = c("Local Road", "Minor Road", "Local Access Road")
openroads.map$local.target    = 'Local'

osni.map = new.env()
osni.map$motorway.src         = c("MOTORWAY", "DUAL_CARR")
osni.map$motorway.target      = 'Motorway'
osni.map$main.src             = c("A_CLASS", "B_CLASS")
osni.map$main.target          = 'Main'
osni.map$local.src            = c("<4M_TARRED", "CL_MINOR")
osni.map$local.target         = 'Local'

for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Processing data for:", params$display.nm,"\n")
  
  if (r == 'Northern Ireland') {
    full.path = get.path(paths$osni.src,'OSNI_Open_Data__50k_Transport_Line','OSNI_Open_Data__50k_Transport_Line.shp')
    rds <- st_read(full.path, quiet=TRUE)
    rds <- rds%>% st_set_crs(NA) %>% st_set_crs(29901)
    rds <- st_transform(rds, 27700)
    
    # Drop TEMA classes that we don't need -- 
    # this includes overpasses because they 
    # will count as 'extra' roads in the next 
    # bit of processing and so we'd double-
    # count the number of roads near each 
    # grid square that had an overpass in or 
    # near it.
    rds <- subset(rds, rds$TEMA %nin% c('CL_RAIL','RL_TUNNEL','UNSHOWN_RL','CL_M_OVER','<4M_T_OVER'))
    cat("   Done loading roads for",r,"\n")
    
    for (c in (grep("src", ls(osni.map), value=TRUE))) {
      cat(c,"\n")
      t = eval(parse(text=paste("osni.map$",sub(".src",".target",c,perl=TRUE),sep="")))
      eval(parse(text=paste("rds$",t," = rds$TEMA %in% osni.map$",c,sep="")))
    }
    
  } else {
    # Now we need to work out which tiles we need -- we
    # do this by using the 100km reference downloaded
    # from GitHub. You can bin the rest.
    rb.shp    <- buffer.region(params)
    osgb.grid <- st_read( get.path(paths$grid.src,c('OSGB_Grids-master','Shapefile','OSGB_Grid_100km.shp')), quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700)
    
    grid.intersects <- osgb.grid %>% st_intersects(rb.shp) %>% lengths()
    grid.tiles      <- sort(osgb.grid$TILE_NAME[ which(grid.intersects==1) ])
    rm(osgb.grid, grid.intersects)
    cat("   Loading roads from tiles",grid.tiles,"\n")
    
    base.path = c(paths$os.src,'oproad_essh_gb','data')
    
    # Get the first tile from the list and 
    # extract only the roads falling within
    # the regional buffer
    rds.fn    <- get.path(base.path, get.file("*_RoadLink.shp",grid.tiles[1]))
    rds       <- st_read(rds.fn, quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700)
    
    # Remove functions we're not interested in
    rds       <- subset(rds, rds$function. %nin% c('Restricted Local Access Road', 'Secondary Access Road'))
    
    # And now select
    is.within <- rds %>% st_intersects(rb.shp) %>% lengths()
    rds       <- subset(rds, is.within==1)
    
    # Get any other tiles from the list and
    # extract only the roads falling within
    # the regional buffer
    for (g in grid.tiles[2:length(grid.tiles)]) {
      rds.fn  <- get.path(base.path, get.file("*_RoadLink.shp",g))
      rds.shp <- st_read(rds.fn, quiet=TRUE, stringsAsFactors=FALSE) %>% st_set_crs(NA) %>% st_set_crs(27700)
      
      # Remove functions we're not interested in
      rds.shp  <- subset(rds.shp, rds.shp$function. %nin% c('Restricted Local Access Road', 'Secondary Access Road'))
      
      # Save the output of st_within and then 
      # convert that to a logical vector to
      # subset
      cat("  Selecting roads in",g,"falling within regional buffer.","\n")
      is.within <- rds.shp %>% st_intersects(rb.shp) %>% lengths()
      rds.shp   <- subset(rds.shp, is.within==1)
      
      rds <- rbind(rds, rds.shp)
      rm(rds.shp, is.within, rds.fn)
    }
    cat("   Done assembling roads data for region...","\n")
    
    for (c in (grep("src", ls(osni.map), value=TRUE))) {
      cat(c,"\n")
      t = eval(parse(text=paste("openroads.map$",sub(".src",".target",c,perl=TRUE),sep="")))
      eval(parse(text=paste("rds$",t," = rds$function. %in% openroads.map$",c,sep="")))
    }
  }
  
  #########################
  # We have the ability to subset the roads by size
  # using the column names Motorway, Main and Local.
  # We can then use different buffers with each. 
  # It's tempting to think that highways would have
  # large buffers, but very few people want to live
  # right next to one, so it also seems like they 
  # should have low weights. In contrast, small roads
  # seem like they'd need small buffers with a fairly
  # large weight in terms of attractiveness for 
  # settlement. At this point, I'd guess that it makes
  # more sense to split them out and record the values 
  # separately before experimenting with different 
  # weights. The downside here is that now we have 
  # a much stronger temporal aspect: because what's 
  # highway now wasn't alway highay...
  #########################
  cat("Loading grid with resolution",g.resolution,"m.\n")
  grid.fn = get.path(paths$grid, get.file(t="{file.nm}-{g.resolution}m-Grid.shp"))
  
  grd <- st_read(grid.fn, quiet=TRUE)
  grd <- grd %>% st_set_crs(NA) %>% st_set_crs(27700)
  
  cat("   Calculating intersections with grid.","\n")
  for (r in road.classes) {
    cat("     Buffering around",r,"classs roads.","\n")
    rds.buff <- st_buffer(st_simplify(subset(rds, rds[[r]]), roads.simplify), eval(parse(text=paste("roads.",tolower(r),".buffer",sep=""))))
    
    cell.intersects <- grd %>% st_intersects(rds.buff) %>% lengths()
    grd[tolower(r)] <- cell.intersects
  }
  cat("   Done.")
  
  cat("   Writing cell intersection values to shapefile.","\n")
  roads.fn = get.path(paths$int, get.file(t="{file.nm}-{g.resolution}m-Road-Grid.shp"))
  st_write(grd, roads.fn, quiet=TRUE, delete_dsn=TRUE)
  rm(grd)
}

cat("Done linking buffered roads to grid.","\n")
