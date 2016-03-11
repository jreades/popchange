#function to smooth and rescale grid iterativly until the thresholds are reached
#doesn't (need to) return any values as the function includes an export to ASCII grid option
gridSmoothingIterative <- function(grid_m_notSplit, longLog = FALSE, grid_m_comb, filename_prefix, grid_r_ID, columnName){
  
#smooth whole data set (B) and rescale
  #create variable by copying original variable
    grid_m_smooth_pop <- grid_m_comb
  #set cells to NA
#    grid_m_smooth_pop[1:nrow(grid_m_smooth_pop),1:ncol(grid_m_smooth_pop)] <- NA
  #get list of all region cells
    all_region_cells <- which(grid_m_notSplit != 0, arr.ind = TRUE)
  #get list of regions from grid_m_notSplit
    list_regions <- sort(unique(c(grid_m_notSplit))) #0 is a special type of region remember
  #set up variable to contain cell references
    #region_cells <- which(!is.na(grid_m_comb), arr.ind = TRUE)
  #get the cells which are in a region (any region)
    #region_cells <- which(grid_m_notSplit != 0, arr.ind = TRUE)
  #for each region, calculate total original population
  for (r in 2:length(list_regions)) {
    #note down region number 
      current_region <- list_regions[r]
    #get the cells which form the current region
      region_cells <- which(grid_m_notSplit == list_regions[r], arr.ind = TRUE)
    #calculate total original population
      originalPop <- sum(grid_m_comb[region_cells])
    #show cells
      #grid_m_comb[region_cells]
    #for each cell
    for (a in 1:length(region_cells[,2])) {
      #check if we are going beyond matrix border
      if (region_cells[a,1]+1 <= nrow(grid_m_notSplit) && region_cells[a,2]+1 <= ncol(grid_m_notSplit)){
        #then run
        #get cells with a 3x3 window
          #current cell
            region_cells[a,]
          #3x3 window
            grid_m_notSplit[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)]
          #population for 3x3 window
            grid_m_comb[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)]
          #smooth by summing and divide by 9, save to grid_m_smooth_pop
          grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] <- sum(grid_m_comb[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)])/9
            #if (is.nan( grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]])) { stop }
      } #end if beyond matrix
    } #end for each cell
    #rescale each region
    #get total smoothed pop
      smoothedPop <- sum(grid_m_smooth_pop[region_cells])
      
      #if smoothed pop is 0, then can't do calculation so skip rescale
      if (smoothedPop != 0) { #if smoothedPop is not 0, carry on
        #for each cell
        for (a in 1:length(region_cells[,2])) {
          #check if we are going beyond matrix border
          if (region_cells[a,1]+1 <= nrow(grid_m_notSplit) && region_cells[a,2]+1 <= ncol(grid_m_notSplit)){
            
            #rescale based on smoothed and original pop
            grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] <- (grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] / smoothedPop) * 100 * (originalPop / 100)
            
          } #end if checking matrix location
        } #end for each cell
      } #end check is smoothedPop = 0
    
  } #end for each region
#recombine smoothed and rescaled values (A)
  #copy inital values to combined values
    #grid_m_comb <- grid_m_pop
    
 # copy original values (not NA) into   grid_m_smooth_pop
    
  
  #update NA values in grid_m_comp (ie orignal values) with smoothed and rescaled data from grid_m_smooth_pop (ie smoothed values)
#    grid_m_comb[which(arr.ind = TRUE, !is.na(grid_m_smooth_pop))] <- grid_m_smooth_pop[which(arr.ind = TRUE, !is.na(grid_m_smooth_pop))]
  
#calc RMSE of just cells in all regions
  rmse <- sqrt(mean((grid_m_comb[all_region_cells]-grid_m_smooth_pop[all_region_cells])^2))

cat("Inital RMSE:",rmse)    

#check wether RMSE is below 0.1, if so then do iterative smoothing, else skip
if (rmse < 0.1) {
  #do iterative smoothing
    #loop
    #set loop counter
    counter <- 0
    while (rmse > 0.001) {
      #advance counter
      counter <- counter + 1
      #smooth & rescale
      
      #create variable by copying original variable
      grid_m_comb <- grid_m_smooth_pop
      #set cells to NA
      #grid_m_comb_smooth[1:nrow(grid_m_comb_smooth),1:ncol(grid_m_comb_smooth)] <- NA
      

      
      #set up variable to contain cell references
      #region_cells <- which(!is.na(grid_m_comb), arr.ind = TRUE)
      
      #get the cells which are in a region (any region)
      #region_cells <- which(grid_m_notSplit != 0, arr.ind = TRUE)
      
      #for each region, calculate total original population
      for (r in 2:length(list_regions)) {
        #note down region number 
        current_region <- list_regions[r]
        #get the cells 
        region_cells <- which(grid_m_notSplit == list_regions[r], arr.ind = TRUE)
        #calculate total original population
        originalPop <- sum(grid_m_comb[region_cells])
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
            grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] <- sum(grid_m_comb[c(region_cells[a,1]-1,region_cells[a,1],region_cells[a,1]+1),c(region_cells[a,2]-1,region_cells[a,2],region_cells[a,2]+1)])/9
          } #end if beyond matrix
        } #end for each cell
        #rescale each region
        #get total smoothed pop
        smoothedPop <- sum(grid_m_smooth_pop[region_cells])
        

        
        #if smoothed pop is 0, then can't do calculation so skip rescale
        if (smoothedPop != 0) { #if smoothedPop is not 0, carry on
          
          #for each cell
          for (a in 1:length(region_cells[,2])) {
            #check if we are going beyond matrix border
            if (region_cells[a,1]+1 <= nrow(grid_m_notSplit) && region_cells[a,2]+1 <= ncol(grid_m_notSplit)){
              #rescale based on smoothed and original pop
              grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] <- (grid_m_smooth_pop[region_cells[a,1],region_cells[a,2]] / smoothedPop) * 100 * (originalPop / 100)
            } #end if checking matrix location
          } #end for each cell
        } #end check is smoothedPop = 0
        
      } #end for each region
      
      #recombine smoothed and rescaled values (A)
      #copy inital values to combined values
    #  grid_m_comb <- grid_m_pop
      #update NA values in grid_m_comp (ie orignal values) with data from grid_m_smooth_pop (ie smoothed values)
    #  grid_m_comb[which(arr.ind = TRUE, !is.na(grid_m_smooth_pop))] <- grid_m_smooth_pop[which(arr.ind = TRUE, !is.na(grid_m_smooth_pop))]
      
      
      
      #calc RMSE
      rmse <- sqrt(mean((grid_m_comb[region_cells]-grid_m_smooth_pop[region_cells])^2))
      #print RMSE and loop number, update status message
      cat("\n","Loop:", counter, "RMSE:",rmse) 
      status <- paste0("Looped ", counter, " times, final RMSE: ",rmse,".")
      
      #update smoothed data into original data (grid_m_comb)
      #grid_m_comb <- grid_m_smooth_pop
  }
  
} else { #RMSE is > 0.1 so iterative smoothing not required
  cat("\n","RMSE:",rmse,"so iterative smoothing not required")
  status <- paste0("RMSE: ",rmse," so iterative smoothing not required")
}



#check total sum
sum(grid_m_smooth_pop[nrow(grid_m_smooth_pop),ncol(grid_m_smooth_pop)], na.rm = TRUE)

sum<- 0
#for (b in 1:length(matrix_loc_i_all)) {
for (i in 1:nrow(grid_m_smooth_pop)) {
  for (j in 1:ncol(grid_m_smooth_pop)) {
    #extract cell indexs
    #i <- matrix_loc_i_all[b]
    #j <- matrix_loc_j_all[b]
    #calc smooth value
    #if the indexes are valid, run, else skip
    #print(grid_m_comb_smooth[i,j])
    sum <- sum + grid_m_smooth_pop[i,j]
  } #end if
} #end if
sum

#write status to tmp file
write(paste0("status <- paste0('",status,"')"), "tmp.R")

#return data
return(grid_m_smooth_pop)
}


