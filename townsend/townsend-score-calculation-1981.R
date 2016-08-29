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
      filename <- paste0("output/townsend/1981/5a_ascii_grid1981_Townsend_Unemploy.asc")
      unemployed_persons <- as.matrix(readGDAL(filename))
    #total economically active
        #comprised of all employed + unemployed
          filename <- paste0("output/townsend/1981/5a_ascii_grid1981_Townsend_Employed.asc")
          all_employed <- as.matrix(readGDAL(filename))
          all_economically_active_persons <- all_employed + unemployed_persons
  #no car or van
    #count households with no car or van
      filename <- paste0("output/townsend/1981/5a_ascii_grid1981_Townsend_NoCar.asc")
      no_car_van_households <- as.matrix(readGDAL(filename))
    #total households (car)
      filename <- paste0("output/townsend/1981/5a_ascii_grid1981_Townsend_Total.asc")
      all_households_car <- as.matrix(readGDAL(filename))
  #non owner occupied households
    #count non owner occupied households
      #tenure_owner_occipied (only variable avaliable)
        filename <- paste0("output/townsend/1981/5a_ascii_grid1981_townsend_TNOwnOcc.asc")
        tenure_owner_occ <- as.matrix(readGDAL(filename))      
      #total
        filename <- paste0("output/townsend/1981/5a_ascii_grid1981_townsend_Total.asc")
        tenure_total <- as.matrix(readGDAL(filename))      
      #calculate difference
        non_owner_occupied_households <- tenure_total - tenure_owner_occ
      #total households (overcrowding)
        filename <- paste0("output/townsend/1981/5a_ascii_grid1981_townsend_Total.asc")
        total_households_tenure <- as.matrix(readGDAL(filename))
  #overcrowding
    #count households Overcrowding
      filename <- paste0("output/townsend/1981/5a_ascii_grid1981_townsend_Oc1_15.asc")
      overcrowded_households <- as.matrix(readGDAL(filename))
    #total households (overcrowding)
      filename <- paste0("output/townsend/1981/5a_ascii_grid1981_townsend_Total.asc")
      total_households_overcrowding <- as.matrix(readGDAL(filename))
      
#Calculations of percentage
  #Unemployed
    unemployed_pc <- (unemployed_persons / all_economically_active_persons) * 100
      #replace instances of all_economically_active_persons = 0 with a value of 0 instead of NaN
        unemployed_pc[which(all_economically_active_persons == 0)] <- 0
  #Non owner occupied
    #replace all negative values of non_owner_occupied_households with 0
        non_owner_occupied_households[which(non_owner_occupied_households < 0)] <- 0
    non_own_occ_pc <- (non_owner_occupied_households / total_households_tenure) * 100
      #replace instances of total_households_tenure = 0 with a value of 0 instead of NaN
        non_own_occ_pc[which(total_households_tenure == 0)] <- 0
  #Non access to car or van
    no_car_van_pc <- (no_car_van_households / all_households_car) * 100
      #replace instances of all_households_car = 0 with a value of 0 instead of NaN
        no_car_van_pc[which(all_households_car == 0)] <- 0
  #Overcrowded
    overcrowded_pc <- (overcrowded_households / total_households_overcrowding) * 100
      #replace instances of total_households_overcrowding = 0 with a value of 0 instead of NaN
        overcrowded_pc[which(total_households_overcrowding == 0)] <- 0

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
     
#Option to export Townsend domain percentages     
   #townsend_z_score <- unemployed_pc
   #townsend_z_score <- overcrowded_pc
   #townsend_z_score <- no_car_van_pc
   #townsend_z_score <- non_own_occ_pc
     
  #set file export name
     filename_part <- "1981_townsend_z_scores"
     #filename_part <- "1981_townsend_unemployed_pc"
     #filename_part <- "1981_townsend_overcrowded_pc"
     #filename_part <- "1981_townsend_no_car_van_pc"
     #filename_part <- "1981_townsend_non_own_occ_pc"

#export to ASC grid
  #replace NA with -1 (NA value for ascii grid)
    townsend_z_score[which(is.na(grid_m_ID))] <- "-1"
    
    #townsend_z_score <- format(townsend_z_score, scientific=FALSE)
    
  #export as ascii grid
    filename <- paste0("output/townsend/",filename_part,".asc")
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
    
  #export as CSV & CSVT
    #export lookup table as CSV
      #extract which grid cells
        grid_ID <- grid_m_ID[which(!is.na(grid_m_ID))]
      #extract grid values
        grid_IDs_matrix <- which(!is.na(grid_m_ID), arr.ind = TRUE)
        grid_values <- townsend_z_score[grid_IDs_matrix]
      #combine together
        tmp <- cbind(grid_ID,grid_values)
      #setup filename
        filename <- paste0("output/townsend/",filename_part,".csv")
    #write CSV file
      write.csv(tmp, filename, row.names = FALSE)
    #setup CSVT file
      #setup filename
        filename <- paste0("output/townsend/",filename_part,".csvt")
      #print info & write file
        cat(paste0("String,Real"), file = filename, sep = "\n")
    
    
    
    
