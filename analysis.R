#Script for census data surface modelling
#Written by Nick Bearman, started 20150604

#I have attempted to setup this project using the principles outlined at:
#https://politicalsciencereplication.wordpress.com/2013/06/04/how-to-make-your-work-reproducible/
#http://nicercode.github.io/blog/2013-04-05-projects/

#this is analysis.R
  #which contains code I am currently working on before it is developed into functions 
  #and stored in /R-functions/, being loaded using source("r-functions/(name).R")

#History
  #Currently (20150604) it loads the Liverpool Knowsley sample data (OA 2011) and ethnic group (2011)
  #swapping out (20150608) to North west GOR
  #(20150624) Code runs for Liverpool and Knowsley subset, reads in data (OA 2011, merged* with landuse data). 
  #Does landuse reallocation, and then reallocation in to 1km grids. 
  #moved code into functions (AreaWeightedSum and AreaWeightedSumLanduse)
  #20150718 all code in functions, tried out some test subsets. 
  #20151007 refined smoothing code to use raster basis rather than vector - much faster
  #20151105 have a version that does more or less everything. More detailed history is in data-notes.txt

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
  source("R-functions/funPreProcessing.R")              #2
  source("R-functions/funAreaWeightedSumLanduse.R")     #3
  source("R-functions/funAreaWeightedSumOverlayGrid.R") #4
  source("R-functions/funAdjustPop.R")                  #5
  source("R-functions/funAllocateToGrid.R")
  source("R-functions/funAllocateContiguousRegions.R")  #7  
  source("R-functions/funGridSmoothing.R")              #8
  source("R-functions/funGridSmoothingIterative.R")     #9
  source("R-functions/funDataSummary.R")                #10  
#1c. Load Data (swap out from data.R file)
  #Setup file names to save
    filename_prefix <- "20160119_EngWal"
  #OA2011 Overlay with Landuse
    #oa2011_weighted <- readShapeSpatial("data/north_west_GOR/oa2011_landuse", proj4string = CRS("+init=epsg:27700"))
  #1km grid  
    grid <- readShapeSpatial("data/gb_2011/grid", proj4string = CRS("+init=epsg:27700")) 
  #OA2011 and grid overlay
    #oa2011_grid <- readShapeSpatial("data/north_west_GOR/oa2011_grid", proj4string = CRS("+init=epsg:27700"))
  #save time for section 1
    sectionTime[1] <- (proc.time() - ptm)[3]

#Section 2. Preprocessing
  cat("\r", "2. PreProcessing")
  sectionName[2] <- "PreProcessing"
  #allocate 1 to each OA, and tidy up landuse data    
    oa2011_weighted <- PreProcessing(oa2011_weighted)
  #save section time
    sectionTime[2] <- (proc.time() - ptm)[3] - sectionTime[1] 
    
#Section 3. Landuse Weighted Populations
  cat("\r", "3. Landuse Weighted Populations")
  sectionName[3] <- "Landuse Weighted Populations"
  #reallocate population based on landuse
    oa2011_weighted <- AreaWeightedSumLanduse(oa2011_weighted)
  #save file write out to see what we have
    filename <- paste0("output/3_oa2011_weighted_",filename_prefix)
    writeSpatialShape(oa2011_weighted, filename)
  #save section time
    sectionTime[3] <- (proc.time() - ptm)[3] - sum(sectionTime[1:2]) 
    
#Section 4. Grid Weighted Populations
  cat("\r", "4. Grid Weighted Populations")
  sectionName[4] <- "Grid Weighted Populations"
  #calculate proportion from oaweighted_2011 to oa2011_grid  
    oa2011_grid <- AreaWeightedSumOverlayGrid(oa2011_weighted,oa2011_grid)
  #save file
    filename <- paste0("output/4_oa2011_grid_",filename_prefix)
    writeSpatialShape(oa2011_grid, filename)
  #save section time
    sectionTime[4] <- (proc.time() - ptm)[3] - sum(sectionTime[1:3]) 
    
### Add in Population Data Here ###
      
#Section 5. Reweight Population
  cat("\r", "5. Reweight Population")
  sectionName[5] <- "Reweight Population"    
  #read in popualtion data
    #data <- read.csv("data/OA_ethnicity_white_british.csv")
    data <- read.csv("data/OA_attributes.csv")
    #count number of attribute columns
        numberAttributeColumns <- length(data) - 1
  #rename columns in oa2011_grid with OA code in to OA11CD, if it exists
    if (which(colnames(oa2011_grid@data) == "OA") > 0 ) {
      names(oa2011_grid@data)[names(oa2011_grid@data)=="OA"] <- "OA11CD"
    } 
  #rename column with proportion of population per OA grid cell from poppr_olg to popProp if it exists
    if (which(colnames(oa2011_grid@data) == "poppr_olg") > 0 ) {
      names(oa2011_grid@data)[names(oa2011_grid@data)=="poppr_olg"] <- "popProp"
    }  
  #reweight to grid
    oa2011_grid <- AdjustPop(oa2011_grid, data, longLog, numberAttributeColumns)
  #rename column with grid ID in it (FID_grid -> ID)
    if (which(colnames(grid@data) == "FID_grid") > 0 ) {
      names(grid@data)[names(grid@data)=="FID_grid"] <- "ID"
    }  
  #ditto for oa2011_grid (rename column with grid ID in it (FID_grid -> ID))
    if (which(colnames(oa2011_grid@data) == "FID_grid") > 0 ) {
      names(oa2011_grid@data)[names(oa2011_grid@data)=="FID_grid"] <- "ID"
    }  
  #allocate to grid shapefile
    grid <- AllocateToGrid(oa2011_grid, grid, longLog, numberAttributeColumns)
  #record which cells are split (based on AllocateToGrid function)
    notSplitGrids <- which(grid@data$notSplit == 1)
  #Save file
    filename <- paste0("output/5_grid_weighted_",filename_prefix)
    writeSpatialShape(grid, filename)
  #save section time 
    sectionTime[5] <- (proc.time() - ptm)[3] - sum(sectionTime[1:4]) 

#Section 6a. Manual Conversion
  cat("\r", "6. Manual Conversion")
  sectionName[6] <- "Manual Conversion"
  #extract column attribute names
    columnNames <- colnames(data)[2:length(data)]
  #print conversion instructions
    filename <- paste0("output/5_grid_weighted_",filename_prefix)
    cat(paste0("Convert vector grid:",filename,".shp"))  
    cat(paste0("Save as raster file (ID): ",filename,"_ID.tif"))  
    cat(paste0("Save as raster file (notSplit): ",filename,"_notSplit.tif"))  
    #loop through columns
      for (i in 1:length(columnNames)){
        cat(paste0("\n","Save as raster file (population): ",filename,"_",columnNames[i],".tif"))  
      }
    
### Convert Data to Ratser Here ###

  #read in raster data
    #raster ID
      filename <- paste0("output/5_grid_weighted_",filename_prefix,"_ID.tif")
      grid_r_ID <- readGDAL(filename)
    #split / not split id
      filename <- paste0("output/5_grid_weighted_",filename_prefix,"_notSplit.tif")
      grid_r_notSplit <- readGDAL(filename)
    #convert ratser to matrix
      grid_m_ID <- as.matrix(grid_r_ID)
      grid_m_notSplit <- as.matrix(grid_r_notSplit)
    #stop time for Section 6 manual conversion
      sectionTime[6] <- (proc.time() - ptm)[3] - sum(sectionTime[1:5])

#Section 7. Allocate Contiguous Regions
  cat("\r", "7. Allocate Contiguous Regions")
  sectionName[7] <- "Allocate Contiguous Regions"   
  #Identify contigious areas and allocate region numbers
    grid_m_notSplit <- AllocateContiguousRegions(grid_m_notSplit,longLog)
  #stop time for Allocate Contiguous Regions
    sectionTime[7] <- (proc.time() - ptm)[3] - sum(sectionTime[1:6])
          
#Sections 8 & 9. Smoothing for each attribute
    #setup section counter to record 8 & 9 for each variable, plus total 8 & 9. 
      sectionNumber <- 7
    #loop through each attribute column
      #grid_r <- NA
      #grid_r[1:length(columnNames)] <- NA
      #for each attribute data
        for (i in 1:length(columnNames)){
          #setup file name
            filename <- paste0("output/5_grid_weighted_",filename_prefix,"_",columnNames[i],".tif")
          #read in data and convert raster to matrix
            grid_r_pop <- readGDAL(filename)
            grid_m_pop <- as.matrix(readGDAL(filename))
          #print info - #8. Grid Smooth (by region) and Rescale
            #advance section number
              sectionNumber <- sectionNumber + 1
            cat("\r", sectionNumber ,"Grid Smooth (by region) and Rescale for",columnNames[i])
            sectionName[sectionNumber] <- paste0("Grid Smooth (by region) and Rescale for ",columnNames[i])
            #do grid smoothing 
              grid_m_comb <- gridSmoothing(grid, grid_m_pop, longLog = FALSE, grid_r_ID, grid_m_notSplit, filename_prefix)
            #stop time 
              sectionTime[sectionNumber] <- (proc.time() - ptm)[3] - sum(sectionTime[1:(sectionNumber-1)], na.rm = TRUE)
          #print info - #9. Iterative Grid Smoothing
            #advance section number
              sectionNumber <- sectionNumber + 1
            cat("\r", sectionNumber ,"Iterative Grid Smoothing for",columnNames[i])
            #do smoothing and return status message
              status <- gridSmoothingIterative(grid_m_notSplit, longLog, grid_m_comb, filename_prefix, grid_r_pop, columnNames[i])
            #set name and add status message  
              sectionName[sectionNumber] <- paste0("Iterative Grid Smoothing for ",columnNames[i]," ",status)
            #stop time 
              sectionTime[sectionNumber] <- (proc.time() - ptm)[3] - sum(sectionTime[1:(sectionNumber-1)], na.rm = TRUE)
        } #end for loop (each attribute column)
      #note down total time for Sections 8 & 9
        #advance section number
          sectionNumber <- sectionNumber + 1
        #total time for section 8 (Grid Smooth (by region) and Rescale) & 9 (Iterative Grid Smoothing)
          sectionName[sectionNumber] <- paste0("Total: Grid Smooth (by region) and Iterative Grid Smoothing")
          sectionTime[sectionNumber] <- sum(sectionTime[8:(sectionNumber-1)], na.rm = TRUE)

#Section 10. Data Summary
  #Stop the clock
    proc.time() - ptm  
  #get total time
    totalTime <- (proc.time() - ptm_total)[3]
  #get list of regions from grid_m_notSplit
    list_regions <- sort(unique(c(grid_m_notSplit))) #0 is a special type of region remember
  #print data summary
    DataSummary(oa2011_weighted, grid, totalTime, sectionTime)
