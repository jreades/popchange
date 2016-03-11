#Function to take population data from oa2011_grid and save into grid
AllocateToGrid <- function(oa2011_grid, grid, longLog = FALSE, numberAttributeColumns){
  #add new field for nonSplit cell
    grid@data$notSplit <- NA
    notSplitGrids <- NA
  #add new field for population & nonSplit cell
    #grid@data$population <- NA
  #get column names & initial length
    columnNames <- colnames(oa2011_grid@data)[(length(oa2011_grid@data)-(2*numberAttributeColumns)+1):(length(oa2011_grid@data)-numberAttributeColumns)]
    oa2011_length <- length(oa2011_grid@data)
    grid_length <- length(grid@data)
  #for each attribute col
    #add the new columns
    for (c in 1:length(columnNames)){
      #create column in grid to save data
        currentGridCol <- grid_length + c
        grid@data[currentGridCol] <- NA
        #rename
        colnames(grid@data)[currentGridCol] <- paste0(columnNames[c])
    } #end for each col
  #for each grid cell
  for (k in 1:length(grid@data$ID)) {
    #Start timer for internal time estimate
      time <- proc.time()   
    #get grid ID
      grid_ID <- grid@data[k,]$ID
    #check whether grid cell is split
      if (length(oa2011_grid@data[which(oa2011_grid@data$ID == grid_ID),]$ID) == 1) {
        #oa2011_grid@data[which(oa2011_grid@data$ID == grid_ID),]$notSplit <- 1
        notSplitGrids[length(notSplitGrids)+1] <- grid@data[k,]$ID
      }
    #for each attribute column
      for (c in 1:length(columnNames)){   
        #work out current column in oa2011_grid@data we are calculating from
          currentColTotal <- oa2011_length - (1 * numberAttributeColumns) + c
        #work out total pop column (where we are saving in Grid)
          currentGridCol <- grid_length + c
      #calc pop total
        if (length(which(oa2011_grid@data$ID == grid_ID)) > 0) { #calc total
          #sum(oa2011_grid@data[which(oa2011_grid@data$ID == grid_ID),]$weightedPopulation)
          #sum(oa2011_grid@data[which(oa2011_grid@data$ID == grid_ID),]$weightedPopulation)
          #sum(oa2011_grid@data[which(oa2011_grid@data$ID == grid_ID),][currentColPop], na.rm = TRUE)
        #save total pop
          #grid@data[which(grid@data$ID == grid_ID),]$population <- sum(oa2011_grid@data[which(oa2011_grid@data$ID == grid_ID),]$weightedPopulation, na.rm = TRUE)
          grid@data[which(grid@data$ID == grid_ID),][currentGridCol] <- sum(oa2011_grid@data[which(oa2011_grid@data$ID == grid_ID),][currentColTotal], na.rm = TRUE)
        } #end if
      } #end for each col
    #calc time left, based on how long it has taken so far (i.e. inital estimates will be rough, but accuracy will improve with running)
      timeLeft <- ( (proc.time() - time)[3]) * (length(grid@data$ID) - k)
    #print information
      cat("\r", "5. Grid", k, "of", length(grid@data$ID),"Est time left:", format(timeLeft, digits = 4, nsmall = 2, trim = TRUE), "seconds", (format(timeLeft/60, digits = 4, nsmall = 2, trim = TRUE)), "min", (format(timeLeft/60/60, digits = 2, nsmall = 1, trim = TRUE)), "hours          ")
    #next grid
  } #end for each grid cell
    #add notSplit to grid
      for (n in 2:length(notSplitGrids)) {
      #find cell and set notSplit
        grid@data[which(grid@data$ID == notSplitGrids[n]),]$notSplit <- 1
      }
  #return data
    return(grid) 
}