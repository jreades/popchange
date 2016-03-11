#function to work out and allocate contigious regions
#in grid_m_notSplit, NA means the cell is split, 1 means the cell is not Split, 2 or more is a region number
AllocateContiguousRegions <- function(grid_m_notSplit, longLog = FALSE){  
  #new region
  newRegion <- 2
  #Start timer for internal time estimate
    time <- proc.time()  
  #repeat for each grid cell 
  for (i in 1:(nrow(grid_m_notSplit)-1)) { #remember rows and cols are reversed for matrix compared to rasters
    for (j in 1:(ncol(grid_m_notSplit)-1)) { 
      #if is a notSplit cell
      if (grid_m_notSplit[i,j] == 1) {
        #are surrounding cells in a region? (are any greater than 1?)
        if (length(which(grid_m_notSplit[c(i-1,i,i+1),c(j-1,j,j+1)] > 1)) > 0) {
          #then allocate the notSplit cells to the existing region
            grid_m_notSplit[i,j] <- grid_m_notSplit[c(i-1,i,i+1),c(j-1,j,j+1)][which(grid_m_notSplit[c(i-1,i,i+1),c(j-1,j,j+1)] > 1)][1]
        } else { #end if
        #else no cells are already allocated to a region
          #start a new region
            #set value to region number
              grid_m_notSplit[i,j] <- newRegion
            #advance new region
              newRegion <- newRegion + 1
        }
      }#end if is a notSplit cell
      #calc time left, based on how long it has taken so far (i.e. inital estimates will be rough, but accuracy will improve with running)
        timeLeft <- ((proc.time() - time)[3] / i) * ((nrow(grid_m_notSplit) - i)/nrow(grid_m_notSplit) * nrow(grid_m_notSplit))
      #print information
        cat("\r", "7. Column", i, "of", nrow(grid_m_notSplit),"Est time left", format(timeLeft, digits = 4, nsmall = 2, trim = TRUE), "seconds", (format(timeLeft/60, digits = 4, nsmall = 2, trim = TRUE)), "min", (format(timeLeft/60/60, digits = 2, nsmall = 1, trim = TRUE)), "hours             (one line for each column)")
    } #end for i
  } #end for j
  
  #B. #need to recheck to combine any contigious areas that are next to each other
    #then check for regions next to each other
    #newRegion contains the number of regions
  
  #for each region
  for (r in 2:(newRegion-1)) {
    #get cells for that region, arr.ind gives us the index for the matrix
      region_cells <- which(grid_m_notSplit == r, arr.ind = TRUE)
    #if region_cells is 0, then next in loop
      if (length(region_cells) == 0) {
        next
      }
    #check 3x3 for each cell
      for (a in 1:length(region_cells[,1])) {
        #grid_m_notSplit[a]
        #grid_m_notSplit[i,j]
        #3x3 window
        #check if we are going beyond matrix border
        if (region_cells[a,1]+1 <= nrow(grid_m_notSplit) && region_cells[a,2]+1 <= ncol(grid_m_notSplit)){
          #then carry on
            #grid 
              grid_m_notSplit[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)]
            #which are not 0?
              non_0 <- which(grid_m_notSplit[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)] != 0)
            #which are a different region?
              diff_region <- which(grid_m_notSplit[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)][non_0] != r)
            #regions to merge
              merge_regions <- grid_m_notSplit[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)][non_0][diff_region]
            #merge will all cells in that region
              #for each entry
              for (m in 1:length(merge_regions)){
                #get cells in that region
                 cells_to_merge <- which(grid_m_notSplit == merge_regions[m], arr.ind = TRUE)
                #change region number
                 grid_m_notSplit[cells_to_merge] <- r
              } #end for each entry
            #overwrite with current region value, including the different ones if they are bigger
              
              #grid_m_notSplit[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)][non_0] <- grid_m_notSplit[region_cells[1],region_cells[2]]
        } #end if in martix
      } #end for each cell
    #go to next region
      cat("\r", "Region ",r,"of ",newRegion)
  } #end for each region
  #return grid variable
    return(grid_m_notSplit)
} #end function