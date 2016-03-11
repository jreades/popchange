#Function to smooth and rescale nonContigious regions across the whole grid
gridSmoothing <- function(grid_m_pop, longLog = FALSE, grid_r_ID, grid_m_notSplit, filename_prefix){
  #Start timer for internal time estimate
    time <- proc.time()  
  #create variable by copying original variable
    grid_m_smooth_pop <- grid_m_pop
  #set cells to NA
    grid_m_smooth_pop[1:nrow(grid_m_smooth_pop),1:ncol(grid_m_smooth_pop)] <- NA
  #get list of regions from grid_m_notSplit
    list_regions <- sort(unique(c(grid_m_notSplit))) #0 is a special type of region remember
  #for each region, calculate total original population
  for (r in 2:length(list_regions)) {
    #note down region number 
    current_region <- list_regions[r]
    #get the cells 
    region_cells <- which(grid_m_notSplit == list_regions[r], arr.ind = TRUE)
    #calculate total original population
    originalPop <- sum(grid_m_pop[region_cells])
    #for each cell
    for (a in 1:length(region_cells[,2])) {
      #check if we are going beyond matrix border
      if (region_cells[a,1]+1 <= nrow(grid_m_notSplit) && region_cells[a,2]+1 <= ncol(grid_m_notSplit)){
        #then run
        #get cells with a 3x3 window
        #current cell
        #region_cells[a,]
        #3x3 window
        #grid_m_notSplit[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)]
        #population for 3x3 window
        #grid_m_pop[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)]
        #smooth by summing and divide by 9, save to grid_m_smooth_pop
        grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] <- sum(grid_m_pop[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)])/9
      } #end if beyond matrix
    } #end for each cell
    #rescale each region
    #get total smoothed pop
    smoothedPop <- sum(grid_m_smooth_pop[region_cells])
    #for each cell
    for (a in 1:length(region_cells[,2])) {
      #check if we are going beyond matrix border
      if (region_cells[a,1]+1 <= nrow(grid_m_notSplit) && region_cells[a,2]+1 <= ncol(grid_m_notSplit)){
        #rescale based on smoothed and original pop
        grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] <- (grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] / smoothedPop) * 100 * (originalPop / 100)
      } #end if checking matrix location
    } #end for each cell
    #calc time left, based on how long it has taken so far (i.e. inital estimates will be rough, but accuracy will improve with running)
      timeLeft <- (((proc.time() - time)[3] / r) * (length(list_regions) - i)/length(list_regions) *length(list_regions))
    #print information
      cat("\r", "7. Region", r, "of", length(list_regions),"Est time left", format(timeLeft, digits = 4, nsmall = 2, trim = TRUE), "seconds", (format(timeLeft/60, digits = 4, nsmall = 2, trim = TRUE)), "min", (format(timeLeft/60/60, digits = 2, nsmall = 1, trim = TRUE)), "hours            (one line for each column)  ")
    
  } #end for each region
  
  #recombine smoothed and rescaled values (A)
  #copy inital values to combined values
  grid_m_comb <- grid_m_pop
  #update NA values in grid_m_comp (ie orignal values) with data from grid_m_smooth_pop (ie smoothed values)
  grid_m_comb[which(arr.ind = TRUE, !is.na(grid_m_smooth_pop))] <- grid_m_smooth_pop[which(arr.ind = TRUE, !is.na(grid_m_smooth_pop))]
  
  #save output
  #save grids output
  #filename <- paste0("output/5_grid_smoothed_",filename_prefix)
  #writeSpatialShape(grid, filename)
  #return grid variable
  return(grid_m_comb)
}