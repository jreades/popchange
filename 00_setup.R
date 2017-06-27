# Set up the data directories for the 
# user and attempt to download the open
# data that we want where it's easy to 
# access.

source('funcs.R')
source('config.R')

for (p in ls(paths)) {
  dir.nm = paste(paths[[p]], collapse="/")
  if (p != 'root'){
    cat("Checking for:",dir.nm,"\n") 
    if (! dir.exists( dir.nm )) {
      cat("     > Creating dir","\n")
      dir.create(dir.nm, showWarnings=TRUE, recursive=TRUE)
    } 
  }
}

# Would be nice to add code to download all of the requisite data as well... one day
# download.file(url, destfile, method, quiet = FALSE, mode = "w"