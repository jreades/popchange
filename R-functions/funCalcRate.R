#function to take count ASCCI grid and calculate rate, using provided denominator
CalcRate <- function(grid_r_ID, columnNames, denominator_col, filename_prefix){
  #setup filename for denominator
    filename <- paste0("output/5a_ascii_grid",filename_prefix,"_",columnNames[denominator_col],".asc")
  #read in as matrix
    demon_data_m <- as.matrix(readGDAL(filename))
  #loop for each column, skipping the denominator column
    for (n in 1:length(columnNames)){
      if (n == denominator_col) {
        #skip, as there no need to calculate a rate for the denominator
      } else { #otherwise continue
    #setup filename for reading in
      filename <- paste0("output/5a_ascii_grid",filename_prefix,"_",columnNames[n],".asc")
    #read in data as matrix
      num_data <- as.matrix(readGDAL(filename))
    #do divison
      output <- num_data / demon_data_m
    #replace NA with -1 (NA value for ascii grid)
      output[which(is.na(grid_m_ID))] <- "-1"
    #output file
      #setup file name
        filename <- paste0("output/5a_ascii_grid",filename_prefix,"_",columnNames[n],"_rate.asc")
      #write header
        cat(paste0("ncols        ",nrow(output)), file = filename, sep = "\n")
        cat(paste0("nrows        ",ncol(output)), file = filename, sep = "\n", append = TRUE)
      #get xll and yll from grid data we read in
        cat(paste0("xllcorner    ",grid_r_ID@bbox[1,1]), file = filename, sep = "\n", append = TRUE)
        cat(paste0("yllcorner    ",grid_r_ID@bbox[2,1]), file = filename, sep = "\n", append = TRUE) 
        cat(paste0("cellsize     ",grid_r_ID@grid@cellsize[1]),  file = filename, sep = "\n", append = TRUE) 
      #ignore NODATA value
        cat(paste0("NODATA_value -1"), file = filename, sep = "\n", append = TRUE) 
    #output data
      #for each row (col in R)
      for (i in 1:ncol(output)) {
        cat(tmp[,i], "\n", file = filename, append = TRUE)
        #next i
        i <- i + 1
      }
    } #end else
  } #end for
} #end function
