#Townsend Calculation
#script to calculate Townsend indicies from source data generated from PopChange project
#see XXXXX file for details

#load libary
  library(rgdal)
#Read in files
  #read in grid template (the raster version of the grid) 
    filename_grid <- paste0("input/grid.tif")
  #test to check filename grid read in and to convert to necessary format
    grid_r_ID <- readGDAL(filename_grid)
    grid_m_ID <- as.matrix(readGDAL(filename_grid))

#Read in source Townsend data
  #unemployment
    #count unemployed        
      filename <- paste0("output/townsend/1991/5a_ascii_grid1991_Townsend_Unemploy.asc")
      unemployed_persons <- as.matrix(readGDAL(filename))
    #total economically active
        #comprised of all employed + unemployed
          filename <- paste0("output/townsend/1991/5a_ascii_grid1991_Townsend_Employed.asc")
          all_employed <- as.matrix(readGDAL(filename))
          all_economically_active_persons <- all_employed + unemployed_persons
  #no car or van
    #count households with no car or van
      filename <- paste0("output/townsend/1991/5a_ascii_grid1991_Townsend_TnNoCar.asc")
      no_car_van_households <- as.matrix(readGDAL(filename))
    #total households (car)
      filename <- paste0("output/townsend/1991/5a_ascii_grid1991_Townsend_TnAll.asc")
      all_households_car <- as.matrix(readGDAL(filename))
  #non owner occupied households
    #count non owner occupied households
      #tenure rent LA
        filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_TnRentLA.asc")
        tenure_rent_LA <- as.matrix(readGDAL(filename))
      #tenure_rent_HA
        filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_TnRentHA.asc")
        tenure_rent_HA <- as.matrix(readGDAL(filename))     
      #tenure_rent_furnished
        filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_TnRntFur.asc")
        tenure_rent_furnished <- as.matrix(readGDAL(filename)) 
      #tenure_rent_unfurnished
        filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_TnRntUFr.asc")
        tenure_rent_unfurnished <- as.matrix(readGDAL(filename)) 
      #tenure_rent_job
        filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_TnRntJob.asc")
        tenure_rent_job <- as.matrix(readGDAL(filename)) 
      #sum non owner occupied
        non_owner_occupied_households <- tenure_rent_LA + tenure_rent_HA + tenure_rent_furnished + tenure_rent_unfurnished + tenure_rent_job
      #total households
        #tenure own outright  
          filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_TnOwnOR.asc")
          tenure_own_outright <- as.matrix(readGDAL(filename)) 
        #tenure own buying
          filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_TnOwnBy.asc")
          tenure_owm_mortgage <- as.matrix(readGDAL(filename)) 
        #sum total
          total_households_tenure <- non_owner_occupied_households + tenure_own_outright + tenure_owm_mortgage
  #overcrowding
    #count households Overcrowding
      filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_Oc1p.asc")
      overcrowded_households <- as.matrix(readGDAL(filename))
    #total households (overcrowding)
      filename <- paste0("output/townsend/1991/5a_ascii_grid1991_townsend_OcTotal.asc")
      total_households_overcrowding <- as.matrix(readGDAL(filename))
      
#Calculations of percentage
  #Unemployed
    unemployed_pc <- unemployed_persons / all_economically_active_persons
  #Non owner occupied
    non_own_occ_pc <- non_owner_occupied_households / total_households_tenure
  #Non access to car or van
    no_car_van_pc <- no_car_van_households / all_households_car
      #replace instances of all_households_car = 0 with a value of 0 instead of NaN
        no_car_van_pc[which(all_households_car == 0)] <- 0
  #Overcrowded
    overcrowded_pc <- overcrowded_households / total_households_overcrowding

#Calculations of logging for unemployed persons and overcrowding
    unemployed_pc_log <- log(unemployed_pc + 1)
    overcrowded_log <- log(overcrowded_pc + 1)

#Convert to z scores
    unemployed_z <- (unemployed_pc_log - mean(unemployed_pc_log, na.rm = TRUE)) / sd(unemployed_pc_log, na.rm = TRUE)
    overcrowded_z <- (overcrowded_log - mean(overcrowded_log, na.rm = TRUE)) / sd(overcrowded_log, na.rm = TRUE)
    no_car_van_z <- (no_car_van_pc - mean(no_car_van_pc, na.rm = TRUE)) / sd(no_car_van_pc, na.rm = TRUE)
    non_own_occ_z <- (non_own_occ_pc - mean(non_own_occ_pc, na.rm = TRUE)) / sd(non_own_occ_pc, na.rm = TRUE)
    
#Sum z scores
    townsend_z_score <- unemployed_z + overcrowded_z + no_car_van_z + non_own_occ_z

#export to ASC grid
  #replace NA with -1 (NA value for ascii grid)
    townsend_z_score[which(is.na(grid_m_ID))] <- "-1"
  #export as ascii grid
    filename <- paste0("output/townsend/1991_townsend_z_scores.asc")
  #rows and cols are inversed for asc grid - see help (?as.raster) and http://stackoverflow.com/questions/14513480/convert-matrix-to-raster-in-r
    cat(paste0("ncols        ",nrow(grid_m_ID)), file = filename, sep = "\n")
    cat(paste0("nrows        ",ncol(grid_m_ID)), file = filename, sep = "\n", append = TRUE)
  #get xll and yll from grid data we read in
    cat(paste0("xllcorner    ",grid_r_ID@bbox[1,1]), file = filename, sep = "\n", append = TRUE)
    cat(paste0("yllcorner    ",grid_r_ID@bbox[2,1]), file = filename, sep = "\n", append = TRUE) 
    cat(paste0("cellsize     ",grid_r_ID@grid@cellsize[1]),  file = filename, sep = "\n", append = TRUE) 
  #ignore NODATA value
    cat(paste0("NODATA_value -1"), file = filename, sep = "\n", append = TRUE) 
  #output data
    #for each row (col in R)
    for (i in 1:ncol(townsend_z_score)) {
      #notes #this section is very slow on a windows machine, but very fast on OSX. 
        cat(townsend_z_score[,i], "\n", file = filename, append = TRUE)
      #next i
        i <- i + 1
      #print i (for testing speed)
      #print(i)
    }
    
