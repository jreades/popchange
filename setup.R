# Set up the data directories for the 
# user and attempt to download the open
# data that we want where it's easy to 
# access.

the.dir  = getwd()
base.dir = 'no-sync'
dirs     = c('OS','OSM','Voronoi','NSPL','Roads','grid','processed','tmp','final')

dirs.iter <- c(paste(base.dir,dirs,sep="/"))

for (d in dirs.iter){
  dir.nm = paste( c(the.dir,d), collapse="/")
  cat(dir.nm,"\n")
  if (! dir.exists( dir.nm )) {
    cat("Creating dir:",dir.nm,"\n")
    dir.create(dir.nm, showWarnings=TRUE, recursive=TRUE)
  } 
}

if (! file.exists(paste(c(os.path, "CTRY_DEC_2011_UK_BGC.shp"), collapse="/"))) {
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat("Have you run the ni-preprocessing.R script yet?\n")
  cat("This is critical to the remaining processes!\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
}

# Would be nice to add code to download all of the requisite data as well... one day