#Script for census data surface modelling
#Written by Nick Bearman, started 20150604

#I have attempted to setup this project using the principles outlined at:
#https://politicalsciencereplication.wordpress.com/2013/06/04/how-to-make-your-work-reproducible/
#http://nicercode.github.io/blog/2013-04-05-projects/

#this is analysis-no-overlay.R
  #which contains a mixture of code I am currently working on and some functions 
  #funcations are stored in /R-functions/, being loaded using source("r-functions/(name).R")

#History
  #Currently (20150604) it loads the Liverpool Knowsley sample data (OA 2011) and ethnic group (2011)
  #swapping out (20150608) to North west GOR
  #(20150624) Code runs for Liverpool and Knowsley subset, reads in data (OA 2011, merged* with landuse data). 
  #Does landuse reallocation, and then reallocation in to 1km grids. 
  #moved code into functions (AreaWeightedSum and AreaWeightedSumLanduse)
  #20150718 all code in functions, tried out some test subsets. 
  #20151007 refined smoothing code to use raster basis rather than vector - much faster
  #20151105 have a version that does more or less everything. More detailed history is in data-notes.txt
  #20160105 lots of minor changes to speed up code. Also works based on overlay input.

#Section 1. Loading Libaries and Data
  cat("\r", "1. Loading Libaries, Functions and Data")
  #Start the clock!
    ptm <- proc.time()
    ptm_total <- proc.time()
  #Setup variables
    sectionTime <- NA
    sectionName <- NA
    sectionName[1] <- "1. Loading Libaries, Functions and Data"
  #set longLog
    longLog <- FALSE
#1a. Load Libaries
  library(maptools)
  library(rgdal)
  library(rgeos)
  library(raster)
#1b. Load Custom written functions
  #source("R-functions/funPreProcessing.R")              #2
  #source("R-functions/funAreaWeightedSumLanduse.R")     #3
  #source("R-functions/funAreaWeightedSumOverlayGrid.R") #4
  #source("R-functions/funAdjustPop.R")                  #2
  #source("R-functions/funAllocateToGrid.R")
  source("R-functions/funAllocateContiguousRegions.R")  #3  
  source("R-functions/funGridSmoothing.R")              #4
  source("R-functions/funGridSmoothingIterative.R")     #5
  source("R-functions/funExportGrid.R")                 #5
  #source("R-functions/funDataSummary.R")                #10  
  source("R-functions/funDataSummaryNoOverlay.R")       #10  

#1c. Load Data (swap out from data.R file)
  #read in OA attributes (the Census variables we are allocating to grid), strip.white = TRUE removes training spaces found in 1981 Census download
    OA_attributes <- read.csv("data/1971/attributes/1971-OA-attributes-sas08.csv", strip.white = TRUE)  
  #read in grid proportion (proportion of each OA in each grid)
    OA_grid <- read.csv("data/1971/1971-OA-grid-proportion.csv")
  #set year
    year <- 1971
  #Setup file names to save
    filename_prefix <- "1971_country_birth"
  #set iterative smoothing
    iterative_smoothing <- FALSE #set to TRUE if you want iterative smoothing
    
  #NO NEED TO EDIT
  #read in grid template (the raster version of the grid) 
    filename_grid <- paste0("data/grid.tif")
  #save time for section 1
    sectionTime[1] <- (proc.time() - ptm)[3]
  #ensure all columns within OA_attributes are numeric
    #for each colum from 2 to end
    for (i in 2:length(OA_attributes)) {
      OA_attributes[,i] <- as.numeric(OA_attributes[,i])
    }

#Section 2. Reweight Population
  cat("\r", "2. Reweight Population")
  sectionName[5] <- "Reweight Population"    
  #count number of attribute columns
    numberAttributeColumns <- length(OA_attributes) - 1
  #get column names
    columnNames <- colnames(OA_attributes)[2:(1+numberAttributeColumns)]
  #check whether OA_attributes stats with GeographyCode
    if (colnames(OA_attributes)[1] == "GeographyCode") { 
      #fine to continue
    } else { #we have a problem
      #print error
      cat("GeographyCode field not found in OA_attributes. Trying alternative versions.")
      if ((colnames(OA_attributes)[1] == "Zone.ID") || ((colnames(OA_attributes)[1] == "Zone.Code"))) { #if zone.id, then use that
        #rename column
        colnames(OA_attributes)[1] <- "GeographyCode"
      } else {
        #print info
        cat("GeographyCode field not found in OA_attributes. Please ensure it is there.")
      }
    }
    
  #merge with OA grid proportion
    grid_OA_att <- merge(OA_attributes,OA_grid,by.x="GeographyCode",by.y="OA") #may need to add all.y = TRUE
  #add new columns to store calc total pops in
    #get total length of grid_OA_att
      length_grid_OA_att <- length(grid_OA_att)
    #for each attribute col
      for (c in 1:length(columnNames)){
        #create column in grid to save data
          currentNewCol <- length_grid_OA_att + c
          grid_OA_att[currentNewCol] <- NA
        #rename to variable + WghPop
          colnames(grid_OA_att)[currentNewCol] <- paste0(columnNames[c],"WghPop")
      } #end for each col
  #calc weigthed population values
    #for each attribute col
      for (c in 1:length(columnNames)){
        #starting with first new column, then for each
          currentNewCol <- 1 + c
        #work out which col we are saving in
          currentSaveCol <- length_grid_OA_att + c
        #do multiple out (OAGEst <- (WtAreaOL / Sum_WtArea) * TotalP)
          grid_OA_att[,currentSaveCol] <- (grid_OA_att$WtAreaOL / grid_OA_att$Sum_WtArea) * grid_OA_att[,currentNewCol]
      } #end for each col
  #aggregate by grid ID (GRIDCODE)
    #create column for count
      grid_OA_att$count <- 1
    #aggregate by grid code columns with wgh pop in
      #based on http://stackoverflow.com/questions/24788450/r-aggregate-data-frame-with-date-column
      grid_OA_att_sum <- aggregate(x = grid_OA_att[(length_grid_OA_att + 0):currentSaveCol+1], #+0 to ensure first OA att col (UsRsPop) is included, +1 to include count
                                 FUN = sum,
                                 by = list(Gridcode = grid_OA_att$GRIDCODE))
  #rename count field to notSplit
    #set all to 0 (i.e. split)
      grid_OA_att_sum$notSplit <- 0
    #update thouse which are not split (where count > 1) to 1
      grid_OA_att_sum[which(grid_OA_att_sum$count == 1),]$notSplit <- 1
    #remove count column
      grid_OA_att_sum[,which(colnames(grid_OA_att_sum) == "count")] <- NULL
  #read in grid template (tmp)    
    grid_r_ID <- readGDAL(filename_grid)
    grid_m_ID <- as.matrix(readGDAL(filename_grid))
  #join to data frame in correct order
    #convert Grid IDs to vector (all, including zeros)
      grid_ID <- as.vector(grid_m_ID)
    #convert to data frame
      grid_IDd <- data.frame(grid_ID)
    #match attribute data to grid IDd
      grid_IDd = data.frame(grid_IDd, grid_OA_att_sum[match(grid_IDd[,"grid_ID"], grid_OA_att_sum[,"Gridcode"]),])
  #extract data to a matrix for notSplit
    #create matrix
      grid_m_notSplit <- matrix(grid_IDd$notSplit, nrow = nrow(grid_m_ID), ncol = ncol(grid_m_ID), byrow = FALSE)
    #remove NAs from grid_m_notSplit
      grid_m_notSplit[which(is.na(grid_m_notSplit))] <- 0
  #extract data for each attribute col
    for (c in 1:length(columnNames)){ 
      #from http://stackoverflow.com/questions/6034655/r-how-to-convert-string-to-variable-name
      #write a script file (1 line in this case) that works with whatever variable name
        #which creates a matrix with the relevant information and saves it
          write(paste0("grid_m_", columnNames[c], " <- matrix(grid_IDd$", columnNames[c], "WghPop, nrow = nrow(grid_m_ID), ncol = ncol(grid_m_ID), byrow = FALSE)"), "tmp/tmp.R")
        #source that script file (to evaluate and load output)
          source("tmp/tmp.R")
        #remove the script file for tidiness
          file.remove("tmp/tmp.R")
      #remove NAs from each
        write(paste0("grid_m_", columnNames[c], "[which(is.na(grid_m_", columnNames[c], "))] <- 0"), "tmp/tmp2.R")
        #source that script file (to evaluate and load output)
          source("tmp/tmp2.R")
        #remove the script file for tidiness
          file.remove("tmp/tmp2.R")
    } #end for each col
  #stop time for 2. Reweight Population
    sectionTime[2] <- (proc.time() - ptm)[3] - sum(sectionTime[1], na.rm = TRUE)
    
#Section 3. Allocate Contiguous Regions
  cat("\r", "3. Allocate Contiguous Regions")
  sectionName[3] <- "Allocate Contiguous Regions" 
  #Check whether contigious regions does not exist already
    if (!exists("grid_m_regions")) { #if grid_m_regions does not exists
      #if it does, load the file
      #get file name
        filename <- paste0("data/",year,"/",year,"-contiguous-regions.RData")
      #check if file exists
      if (file.exists(paste0(filename))) {
        #then load
        load(filename)
      }
    }
  #Check again whether it exists
    if (!exists("grid_m_regions")) { #if grid_m_regions does not exist (still)
      #if it still doesn't exisit, we need to run code
        #Identify contigious areas and allocate region numbers
      grid_m_regions <- AllocateContiguousRegions(grid_m_notSplit,longLog)
        #and then save output
          save(grid_m_regions, file = filename)
    } else { #else we can carry on 
    }

  #stop time for Allocate Contiguous Regions
    sectionTime[3] <- (proc.time() - ptm)[3] - sum(sectionTime[1:2], na.rm = TRUE)
          
#Sections 4 & 5. Smoothing for each attribute
    #setup section counter to record 4 & 5 for each variable, plus total 5 & 5. 
      sectionNumber <- 3 #set so first section is #8
    #loop through each attribute column
      #grid_r <- NA
      #grid_r[1:length(columnNames)] <- NA
      #for each attribute data
        for (i in 1:length(columnNames)){
          #setup file name
            #filename <- paste0("output/5_grid_weighted_",filename_prefix,"_",columnNames[i],".tif")
          #read in data and convert raster to matrix
            #grid_r_pop <- readGDAL(filename)
            #grid_m_pop <- as.matrix(readGDAL(filename))
          #select data
          #grid_m_pop <- grid_m_UslRsPop ###TEMP
            #write a script file (1 line in this case) that works with whatever variable name
            write(paste0("grid_m_pop <- grid_m_",columnNames[i]), "tmp.R")
            #source that script file
            source("tmp.R")
            #remove the script file for tidiness
            file.remove("tmp.R")
          #print info - #8. Grid Smooth (by region) and Rescale
            #advance section number
              sectionNumber <- sectionNumber + 1
            cat("\r", sectionNumber ,"Grid Smooth (by region) and Rescale for",columnNames[i])
            sectionName[sectionNumber] <- paste0("Grid Smooth (by region) and Rescale for ",columnNames[i])
            #do grid smoothing 
              #grid_m_comb <- gridSmoothing(grid, grid_m_pop, longLog = FALSE, grid_r_ID, grid_m_regions, filename_prefix)
              grid_m_comb <- gridSmoothing(grid_m_pop, longLog = FALSE, grid_r_ID, grid_m_regions, filename_prefix)
            #stop time 
              sectionTime[sectionNumber] <- (proc.time() - ptm)[3] - sum(sectionTime[1:(sectionNumber-1)], na.rm = TRUE)
          
          #5. Iterative Grid Smoothing
              #check whether we need to do iterative smoothing
              if (iterative_smoothing) { #if true, then do smoothing
                #advance section number
                  sectionNumber <- sectionNumber + 1
                  cat("\r", sectionNumber ,"Iterative Grid Smoothing for",columnNames[i])
                #do smoothing and return status message
                  grid_m_smooth_pop <- gridSmoothingIterative(grid_m_regions, longLog, grid_m_comb, filename_prefix, grid_r_ID, columnNames[i])
                #source that script file (to load status)
                  source("tmp.R")
                #remove the script file for tidiness
                  file.remove("tmp.R")
                #set name and add status message  
                  sectionName[sectionNumber] <- paste0("Iterative Grid Smoothing for ",columnNames[i]," ",status)
              } else {
                #rename grid_m_comb to grid_m_smooth_pop for output
                grid_m_smooth_pop <- grid_m_comb
              }
             #export grid
              ExportGrid(grid_m_smooth_pop, filename_prefix, grid_r_ID, columnNames[i])
            #print info
              cat("\n", "5. Column", i, "of", length(columnNames))
          #stop time 
            sectionTime[sectionNumber] <- (proc.time() - ptm)[3] - sum(sectionTime[1:(sectionNumber-1)], na.rm = TRUE)
        } #end for loop (each attribute column)
      #note down total time for Sections 8 & 9
        #advance section number
          sectionNumber <- sectionNumber + 1
        #total time for section 8 (Grid Smooth (by region) and Rescale) & 9 (Iterative Grid Smoothing)
          sectionName[sectionNumber] <- paste0("Total: Grid Smooth (by region) and Iterative Grid Smoothing")
          sectionTime[sectionNumber] <- sum(sectionTime[8:(sectionNumber-1)], na.rm = TRUE)

#Section 6. Data Summary
  #Stop the clock
    proc.time() - ptm  
  #get total time
    totalTime <- (proc.time() - ptm_total)[3]
  #get list of regions from grid_m_regions
    list_regions <- sort(unique(c(grid_m_regions))) #0 is a special type of region remember
  #print data summary
    DataSummaryNoOverlay(totalTime, sectionTime)
