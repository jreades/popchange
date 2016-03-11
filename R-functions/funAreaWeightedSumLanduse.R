#function to update weighted populations based on land use
AreaWeightedSumLanduse <- function(oa2011_weighted){
  #setup field for weigthed populations
  oa2011_weighted@data$weightedPopulation <- NA
  #work out area of each polygon
  oa2011_weighted@data$area <- gArea(oa2011_weighted, byid = TRUE)
  #find out how many areas each OA has been split into
  freqtable <-  as.data.frame(table(oa2011_weighted@data$OA))
  #remove any 0 entries (only for subsets)  
  freqtable <- freqtable[which(freqtable$Freq != 0),]
  #loop through each OA (or OA set) and reallocate population  
  #Start timer for internal time estimate
    time <- proc.time()
  for (i in 1:length(freqtable$Var1)) { 
    #extract sub table for current OA #current OA = freqtable[i,1]
    currentOA <- oa2011_weighted@data[which(oa2011_weighted@data$OA == freqtable[i,1]),]
    #calc time left, based on how long it has taken so far (i.e. inital estimates will be rough, but accuracy will improve with running)
      timeLeft <-((proc.time() - time)[3] / i) * ((length(freqtable$Var1) - i)/length(freqtable$Var1) * length(freqtable$Var1))
    #print loop number for each interation of the loop
      cat("\r", "3.",i , "of", length(freqtable$Var1), "split into", length(currentOA$OA), "Est time left:", format(timeLeft, digits = 4, nsmall = 2, trim = TRUE), "seconds", (format(timeLeft/60, digits = 4, nsmall = 2, trim = TRUE)), "min", (format(timeLeft/60/60, digits = 2, nsmall = 1, trim = TRUE)), "hours   ") 
    #if number of OA = 1 then, just use existing pop value
    if (length(currentOA$OA11CD) == 1) {
      currentOA$weightedPopulation <- currentOA$population
    } else {
      #if number of OA > 1, then we need to do something else  
      #get total area and total urban area and total rural area (rural is everything else)
      totalarea <- sum(currentOA$area)
      totalurbanarea <- sum(currentOA[which(currentOA$landuse == "urban"),]$area)
      totallakearea <- sum(currentOA[which(currentOA$landuse == "lakewood"),]$area)
      totalruralarea <- sum(currentOA[which(is.na(currentOA$landuse)),]$area)
      #get total pop for OA (can just select first entry)
      population <- currentOA$population[1]
      #assign lakewood areas a value of 0
      currentOA[which(currentOA$landuse == "lakewood"),]$weightedPopulation <- 0 * currentOA[which(currentOA$landuse == "lakewood"),]$population #this line stops R objecting if there are no areas of lakewood
      #assign urban locations 0.9 of the population, weighted by area
      currentOA[which(currentOA$landuse == "urban"),]$weightedPopulation <- (population * 0.9)*(currentOA[which(currentOA$landuse == "urban"),]$area/totalurbanarea)
      #if there are no rural areas
      if (totalruralarea == 0) {
        #assign everything to the urban areas, weighted by area
        currentOA[which(currentOA$landuse == "urban"),]$weightedPopulation <- (population)*(currentOA[which(currentOA$landuse == "urban"),]$area/totalurbanarea)
        #if we have urban areas,
      } else if (totalurbanarea > 0) {
        #assign rural araes 0.1 population, weigthed by area
        currentOA[which(is.na(currentOA$landuse)),]$weightedPopulation <- (population * 0.1)*(currentOA[which(is.na(currentOA$landuse)),]$area/totalruralarea)
      } else {
        #else assign all to rural areas, weighted by area
        currentOA[which(is.na(currentOA$landuse)),]$weightedPopulation <- (population)*(currentOA[which(is.na(currentOA$landuse)),]$area/totalruralarea)
      } #end if (totalurbanarea > 0) {
    } #end if (length(currentOA$OA11CD) == 1) {
    #match currentOA back on to oa2011_weigthed using internal rownames       
    oa2011_weighted@data[which(oa2011_weighted@data$OA == freqtable[i,1]),] <- currentOA
  } #end for (i in 1:length(freqtable$Var1)) { 
  #check that original population and weighted population is the same 
  sum(oa2011_weighted@data$weightedPopulation, na.rm = TRUE)
  #return grid variable
  return(oa2011_weighted)
}