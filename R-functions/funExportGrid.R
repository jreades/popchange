#function to export data as ASCII grid
ExportGrid <- function(grid_m_smooth_pop, filename_prefix, grid_r_ID, columnName){
  #replace NA with -1 (NA value for ascii grid)
  grid_m_smooth_pop[which(is.na(grid_m_ID))] <- "-1"
#export as ascii grid
filename <- paste0("output/5a_ascii_grid",filename_prefix,"_",columnName,".asc")
#filename <- "20151006-test-b.asc"
#rows and cols are inversed for asc grid - see help (?as.raster) and http://stackoverflow.com/questions/14513480/convert-matrix-to-raster-in-r
cat(paste0("ncols        ",nrow(grid_m_smooth_pop)), file = filename, sep = "\n")
cat(paste0("nrows        ",ncol(grid_m_smooth_pop)), file = filename, sep = "\n", append = TRUE)
#get xll and yll from grid data we read in
cat(paste0("xllcorner    ",grid_r_ID@bbox[1,1]), file = filename, sep = "\n", append = TRUE)
cat(paste0("yllcorner    ",grid_r_ID@bbox[2,1]), file = filename, sep = "\n", append = TRUE) 
cat(paste0("cellsize     ",grid_r_ID@grid@cellsize[1]),  file = filename, sep = "\n", append = TRUE) 
#ignore NODATA value
cat(paste0("NODATA_value -1"), file = filename, sep = "\n", append = TRUE) 
#output data
#for each row (col in R)
for (i in 1:ncol(grid_m_smooth_pop)) {
  cat(grid_m_smooth_pop[,i], "\n", file = filename, append = TRUE)
  #next i
  i <- i + 1
}

#return data
#return(status)
}