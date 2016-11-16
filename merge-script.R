#Script to merge multiple CSV files together

#Setup new working directory
  #get working directory
    currentWorkingDirectory <- getwd()
  #set to /merge
    setwd(paste0(currentWorkingDirectory,"/merge"))
#Get list of filenames to be merged
  filenames <- list.files(path = ".") 
#Merge files
  tmp <- do.call("cbind", lapply(filenames, read.csv, header = TRUE)) 
#Rename first col to grid_ID_keep
  colnames(tmp)[1] <- "grid_ID_keep"
#remove gird_ID cols
  tmp2 <- subset(tmp, select=-c(grid_ID))
  tmp2 <- tmp[ , -which(names(tmp) %in% c("grid_ID"))]
#apply names based on filenames
  colnames(tmp2) <- filenames
  #need to add grid_id to output.csv manually
#export
  #setup filename
    filename <- paste0("output.csv")
  #write CSV file
    write.csv(tmp2, filename, row.names = FALSE)
#Reset working directory
  setwd(currentWorkingDirectory)
