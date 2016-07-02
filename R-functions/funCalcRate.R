#function to take count ASCCI grid and calculate percentage, using provided denominator
CalcRate <- function(grid_r_ID, columnNames, denom_col, filename_prefix){
  if (denom_col == 0) {
    #if denom is 0, then stop (as demon not needed) otherwise carry on    
  } else {
    #carry on
    #setup filename for denominator
      filename <- paste0("output/5a_ascii_grid",filename_prefix,"_",columnNames[denom_col],".asc")
    #read in as matrix
      demon_data_m <- as.matrix(readGDAL(filename))
    #loop for each column, skipping the denominator column
      for (n in 1:length(columnNames)){
        if (n == denom_col) {
          #skip, as there no need to calculate a rate for the denominator
        } else { #otherwise continue
      #setup filename for reading in
        filename <- paste0("output/5a_ascii_grid",filename_prefix,"_",columnNames[n],".asc")
      #read in data as matrix
        num_data <- as.matrix(readGDAL(filename))
      #do divison
        output <- (num_data / demon_data_m) * 100
      #if any were 0, then replace them with 0 (as otherwise they will come out with NaN or missing)
        output[which(num_data == 0 )] <- 0
      #replace NA with -1 (NA value for ascii grid)
        output[which(is.na(grid_m_ID))] <- "-1"
      #output file
        #setup file name
          filename <- paste0("output/5a_ascii_grid",filename_prefix,"_",columnNames[n],"_pc.asc")
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
        #print
          print(paste0("Writing out data for ",filename_prefix," ",columnNames[n], " percentages"))
        #for each row (col in R)
        for (i in 1:ncol(output)) {
          cat(output[,i], "\n", file = filename, append = TRUE)
          #next i
          i <- i + 1
        }
      } #end else  if (n == denom_col) {
    } #end for
  } #end else if (denom_col = 0) {
} #end function
