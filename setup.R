# Set up the data directories for the 
# user and attempt to download the open
# data that we want where it's easy to 
# access.

the.dir  = getwd()
base.dir = 'no-sync'
dirs     = c('OS','OSM','Voronoi','NSPL','Roads','grid','processed')

dirs.iter <- c(base.dir, paste(base.dir,dirs,sep="/"))

for (d in dirs.iter){
  if (! dir.exists( paste(the.dir,'no-sync',sep="/") )) {
    dir.create(paste(the.dir,'no-sync',sep="/"), showWarnings=TRUE, recursive=TRUE)
  } 
}

# Would be nice to add code to download all of the requisite data as well... one day