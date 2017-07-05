######################################################
######################################################
# This stage seeks to pull together all of the data that
# we've generated in the previous steps so that it's 
# readily accessible in a single shapefile and can be
# manipulated in a more flexible way (esp. if we want
# to tweak the weights!).
######################################################
######################################################
#rm(list = ls()) # Clear the workspace
source('funcs.R')
source('config.R')

params = set.params(r)
cat("\n","======================\n","06:Integration (", params$display.nm,")\n")

# Load Grid
grd <- st_read(get.path(paths$grid, get.file(t="{file.nm}-{g.resolution}m-Grid.shp")), quiet=TRUE)
grd <- grd %>% st_set_crs(NA) %>% st_set_crs(crs.gb)
cat("Loaded grid containing",nrow(grd),"cells","\n")

# Load Roads
rds <- data.table::fread(get.path(paths$int,get.file(t="{file.nm}-{g.resolution}m-*-Grid.csv",'Road')))
cat("Loaded roads grid containing",nrow(rds),"cells","\n")
dt.sf = grd %>% dplyr::left_join(rds, by="id")
#st_write(dt.sf, 'test.shp', delete_dsn=TRUE, quiet=TRUE)

# Load OSM
osm <- data.table::fread(get.path(paths$int,get.file(t="{file.nm}-{g.resolution}m-*-Grid.csv",'Use_Classes')))
cat("Loaded OSM grid containing",nrow(osm),"cells","\n")
dt.sf2 = dt.sf %>% dplyr::left_join(osm, by="id")
names(dt.sf2) <- substring(gsub('_','',names(dt.sf2)), 1, 10) # Problem with long column names and/or underscores
#st_write(dt.sf2, 'test2.shp', delete_dsn=TRUE, quiet=TRUE)

# Load NSPL
for (y in census.years) {
  nspl.fn = get.path(paths$int,get.file(t="{file.nm}-{g.resolution}m-*-Grid.csv",'NSPL',y))
  if (file.exists(nspl.fn)) {
    nspl <- data.table::fread(nspl.fn)
    cat("Loaded NSPL grid for",y,"containing",nrow(nspl),"cells","\n")
    dt.sf3 = dt.sf2 %>% dplyr::left_join(nspl, by="id")
    dt.sf3[is.na(dt.sf3)] = 0 # Avoid mixed NA/0 challenges
    cat("Writing shapefile to 'final' directory...")
    st_write(dt.sf3, get.path(paths$final,get.file(t="{file.nm}-{g.resolution}m-Grid-*.shp",y)), delete_dsn=TRUE, quiet=TRUE)
  } else {
    cat("Skipping year",y,"since no NSPL data found for that year.","\n")  
  }
}