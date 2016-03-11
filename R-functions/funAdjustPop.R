#Function to link OA spatial data to population attribute data
#Updated to allow multiple columns within data
AdjustPop <- function(oa2011_grid, data, longLog = FALSE, numberAttributeColumns){
    #head(data)
    #head(oa2011_grid@data)
  #merge data (OAs will be repeated) in oa2011_grid
    oa2011_grid@data = data.frame(oa2011_grid@data, data[match(oa2011_grid@data[,"OA11CD"], data[,1]),])
  #get column names & initial length
    columnNames <- colnames(data)[2:length(data)]
    oa2011_length <- length(oa2011_grid@data)
  #for each column
    for (c in 1:length(columnNames)){
    #work out current column in oa2011_grid@data we are creating and calculating
      currentCol <- oa2011_length + c
    #create column
      oa2011_grid@data[currentCol] <- NA
    #rename
      colnames(oa2011_grid@data)[currentCol] <- paste0(columnNames[c],"WeightedPop")
    #multiply out
      oa2011_grid@data[currentCol] <- oa2011_grid@data[which(colnames(oa2011_grid@data) == columnNames[c])] * oa2011_grid@data$popProp
    } #end for each column
  #return data
    return(oa2011_grid) 
}