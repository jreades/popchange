#function to allocate proportion population from oa2011_weigthed to oa2011_grid
AreaWeightedSumOverlayGrid <- function(oa2011_weigthed, oa2011_grid){
  #calc area
    oa2011_grid@data$area <- gArea(oa2011_grid, byid = TRUE)
  #setup field to save proportion population
   oa2011_grid$popProp <- NA
  #get unique list of OAs
    #uniqueOA <- oa2011_weighted$OA11CD
    uniqueOA <- oa2011_grid$OA11CD
    #changed from uniqueOA <- oa2011_weighted$OA 20151022 1427
    uniqueOA <- unique(uniqueOA)
  #Start timer for internal time estimate
    time <- proc.time()
  #loop through each OA
    for (k in 1:length(uniqueOA)) { #for each OA
    #extract grids that cover current OA
      current_oa <- oa2011_grid@data[which(oa2011_grid@data$OA11CD == uniqueOA[k]),]
      #apply weights to different areas 
        #if there is only one entry, then it gets all the population proportion
          if (length(current_oa$landuse) == 1) {
            current_oa$popProp <- 1
          }
        #urban gets 0.9 between them based on area if there are rows
          if (length(current_oa[which(current_oa$landuse == "urban"),]$landuse) > 0) {
            current_oa[which(current_oa$landuse == "urban"),]$popProp <- 0.9 * (current_oa[which(current_oa$landuse == "urban"),]$area / sum(current_oa[which(current_oa$landuse == "urban"),]$area))
          }
        #woodlake gets 0.0 between them based on area if there are rows
          if (length(current_oa[which(current_oa$landuse == "lake" | current_oa$landuse == "woodland"),]$landuse) > 0) {
            current_oa[which(current_oa$landuse == "lake" | current_oa$landuse == "woodland"),]$popProp <- 0
          }
        #rest gets rest (0.1) between them based on area if there are rows
          current_oa[which(is.na(current_oa$landuse)),]$popProp <- 0.1 * (current_oa[which(is.na(current_oa$landuse)),]$area / sum(current_oa[which(is.na(current_oa$landuse)),]$area))
        #unless if there is no urban, then apply all population to rest (i.e. ones that are NA)
          if (length(current_oa[which(current_oa$landuse == "urban"),]$landuse) == 0) {
              current_oa[which(is.na(current_oa$landuse)),]$popProp <- current_oa[which(is.na(current_oa$landuse)),]$area / sum(current_oa[which(is.na(current_oa$landuse)),]$area)
          }
        #unless if there is no other, then apply all population to urban
          if (length(current_oa[which(is.na(current_oa$landuse)),]$landuse) == 0) {
            current_oa[which(current_oa$landuse == "urban"),]$popProp <- 1.0 * (current_oa[which(current_oa$landuse == "urban"),]$area / sum(current_oa[which(current_oa$landuse == "urban"),]$area))
          }
      #check pop which should sum to 1 for each OA if reallocation is correct, if not stop
          if (sum(current_oa$popProp) != 1) {
            stop
          }
      #save new population proportion, match current_oa back on to oa2011_grid       
        oa2011_grid@data[which(oa2011_grid@data$OA11CD == uniqueOA[k]),] <- current_oa
      #calc time left, based on how long it has taken so far (i.e. inital estimates will be rough, but accuracy will improve with running)
        timeLeft <-((proc.time() - time)[3] / k) * ((length(uniqueOA) - k)/length(uniqueOA) * length(uniqueOA))
      #print information
        cat("\r", "4. OA", k, "of", length(uniqueOA), "contains", length(oa2011_grid@data[which(oa2011_grid@data$OA11CD == uniqueOA[k]),]$area), "grid cells","Est time left:", format(timeLeft, digits = 4, nsmall = 2, trim = TRUE), "seconds", (format(timeLeft/60, digits = 4, nsmall = 2, trim = TRUE)), "min", (format(timeLeft/60/60, digits = 2, nsmall = 1, trim = TRUE)), "hours   ")
  } #end for OA  
  #return variable
    return(oa2011_grid)
} #end function