#Script for taking Townsend data and collating to one table

#Requirements
#A single table with total counts, the four Townsend input %s (employment, car access, tenure, 
#overcrowding) and the Townsend score itself for 1971, 1981, 1991, 2001 and 2011. I will 
#also need the grids for each year for total persons, unemployment % and Townsend.

# Read in grid_ID
  #filename & read in
    filename <- paste0("output/townsend/1971_townsend_z_scores.csv")
    grid_ID <- read.csv(filename)
  #drop ID column
    grid_ID$grid_values <- NULL
    
# Read in townsend z scores
  #1971
    #filename & read in
      filename <- paste0("output/townsend/1971_townsend_z_scores.csv")
      townsend_z_1971 <- read.csv(filename)
    #drop ID column
      townsend_z_1971$grid_ID <- NULL
  #1981
    #filename & read in
      filename <- paste0("output/townsend/1981_townsend_z_scores.csv")
      townsend_z_1981 <- read.csv(filename)
    #drop ID column
      townsend_z_1981$grid_ID <- NULL
  #2001
    #filename & read in
      filename <- paste0("output/townsend/2001_townsend_z_scores.csv")
      townsend_z_2001 <- read.csv(filename)
    #drop ID column
      townsend_z_2001$grid_ID <- NULL
  #2001
    #filename & read in
      filename <- paste0("output/townsend/2001_townsend_z_scores.csv")
      townsend_z_2001 <- read.csv(filename)
    #drop ID column
      townsend_z_2001$grid_ID <- NULL
  #2011
    #filename & read in
      filename <- paste0("output/townsend/2011_townsend_z_scores.csv")
      townsend_z_2011 <- read.csv(filename)
    #drop ID column
      townsend_z_2011$grid_ID <- NULL
      
#Read in townsend percentages
  #1971    
    #no_car_van
      #filename & read in
        filename <- paste0("output/townsend/1971_outputs/1971_townsend_no_car_van_pc.csv")
        no_car_van_pc_1971 <- read.csv(filename)
      #drop ID column
        no_car_van_pc_1971$grid_ID <- NULL  
    #non_own_occ
      #filename & read in
        filename <- paste0("output/townsend/1971_outputs/1971_townsend_non_own_occ_pc.csv")
        non_own_occ_pc_1971 <- read.csv(filename)
      #drop ID column
        non_own_occ_pc_1971$grid_ID <- NULL  
    #overcrowded
      #filename & read in
        filename <- paste0("output/townsend/1971_outputs/1971_townsend_overcrowded_pc.csv")
        overcrowded_pc_1971 <- read.csv(filename)
      #drop ID column
        overcrowded_pc_1971$grid_ID <- NULL  
    #unemployed
      #filename & read in
        filename <- paste0("output/townsend/1971_outputs/1971_townsend_unemployed_pc.csv")
        unemployed_pc_1971 <- read.csv(filename)
      #drop ID column
        unemployed_pc_1971$grid_ID <- NULL  
  #1981    
    #no_car_van
      #filename & read in
        filename <- paste0("output/townsend/1981_outputs/1981_townsend_no_car_van_pc.csv")
        no_car_van_pc_1981 <- read.csv(filename)
      #drop ID column
        no_car_van_pc_1981$grid_ID <- NULL  
    #non_own_occ
      #filename & read in
        filename <- paste0("output/townsend/1981_outputs/1981_townsend_non_own_occ_pc.csv")
        non_own_occ_pc_1981 <- read.csv(filename)
      #drop ID column
        non_own_occ_pc_1981$grid_ID <- NULL  
    #overcrowded
      #filename & read in
        filename <- paste0("output/townsend/1981_outputs/1981_townsend_overcrowded_pc.csv")
        overcrowded_pc_1981 <- read.csv(filename)
      #drop ID column
        overcrowded_pc_1981$grid_ID <- NULL  
    #unemployed
      #filename & read in
        filename <- paste0("output/townsend/1981_outputs/1981_townsend_unemployed_pc.csv")
        unemployed_pc_1981 <- read.csv(filename)
      #drop ID column
        unemployed_pc_1981$grid_ID <- NULL 
  #1991    
    #no_car_van
      #filename & read in
        filename <- paste0("output/townsend/1991_outputs/1991_townsend_no_car_van_pc.csv")
        no_car_van_pc_1991 <- read.csv(filename)
      #drop ID column
        no_car_van_pc_1991$grid_ID <- NULL  
    #non_own_occ
      #filename & read in
        filename <- paste0("output/townsend/1991_outputs/1991_townsend_non_own_occ_pc.csv")
        non_own_occ_pc_1991 <- read.csv(filename)
      #drop ID column
        non_own_occ_pc_1991$grid_ID <- NULL  
    #overcrowded
      #filename & read in
        filename <- paste0("output/townsend/1991_outputs/1991_townsend_overcrowded_pc.csv")
        overcrowded_pc_1991 <- read.csv(filename)
      #drop ID column
        overcrowded_pc_1991$grid_ID <- NULL  
    #unemployed
      #filename & read in
        filename <- paste0("output/townsend/1991_outputs/1991_townsend_unemployed_pc.csv")
        unemployed_pc_1991 <- read.csv(filename)
      #drop ID column
        unemployed_pc_1991$grid_ID <- NULL  
   #2001    
    #no_car_van
      #filename & read in
        filename <- paste0("output/townsend/2001_outputs/2001_townsend_no_car_van_pc.csv")
        no_car_van_pc_2001 <- read.csv(filename)
      #drop ID column
        no_car_van_pc_2001$grid_ID <- NULL  
    #non_own_occ
      #filename & read in
        filename <- paste0("output/townsend/2001_outputs/2001_townsend_non_own_occ_pc.csv")
        non_own_occ_pc_2001 <- read.csv(filename)
      #drop ID column
        non_own_occ_pc_2001$grid_ID <- NULL  
    #overcrowded
      #filename & read in
        filename <- paste0("output/townsend/2001_outputs/2001_townsend_overcrowded_pc.csv")
        overcrowded_pc_2001 <- read.csv(filename)
      #drop ID column
        overcrowded_pc_2001$grid_ID <- NULL  
    #unemployed
      #filename & read in
        filename <- paste0("output/townsend/2001_outputs/2001_townsend_unemployed_pc.csv")
        unemployed_pc_2001 <- read.csv(filename)
      #drop ID column
        unemployed_pc_2001$grid_ID <- NULL  
  #2011    
    #no_car_van
      #filename & read in
        filename <- paste0("output/townsend/2011_outputs/2011_townsend_no_car_van_pc.csv")
        no_car_van_pc_2011 <- read.csv(filename)
      #drop ID column
        no_car_van_pc_2011$grid_ID <- NULL  
    #non_own_occ
      #filename & read in
        filename <- paste0("output/townsend/2011_outputs/2011_townsend_non_own_occ_pc.csv")
        non_own_occ_pc_2011 <- read.csv(filename)
      #drop ID column
        non_own_occ_pc_2011$grid_ID <- NULL  
    #overcrowded
      #filename & read in
        filename <- paste0("output/townsend/2011_outputs/2011_townsend_overcrowded_pc.csv")
        overcrowded_pc_2011 <- read.csv(filename)
      #drop ID column
        overcrowded_pc_2011$grid_ID <- NULL  
    #unemployed
      #filename & read in
        filename <- paste0("output/townsend/2011_outputs/2011_townsend_unemployed_pc.csv")
        unemployed_pc_2011 <- read.csv(filename)
      #drop ID column
        unemployed_pc_2011$grid_ID <- NULL  

#Read in total counts
  #1971
    #filename & read in
      filename <- paste0("output/total-population/1971/lookup_1971_Total_Population_PBPres.csv")
      total_population_1971 <- read.csv(filename)
    #drop ID column
      total_population_1971$grid_ID <- NULL
  #1981
    #filename & read in
      filename <- paste0("output/total-population/1981/lookup_1981_Total_Population_PBPres.csv")
      total_population_1981 <- read.csv(filename)
    #drop ID column
      total_population_1981$grid_ID <- NULL
  #1991
    #filename & read in
      filename <- paste0("output/total-population/1991/lookup_1991_Total_Population_TPPres.csv")
      total_population_1991 <- read.csv(filename)
    #drop ID column
      total_population_1991$grid_ID <- NULL
  #2001      
    #filename & read in
      filename <- paste0("output/total-population/2001/lookup_2001_Total_Population_UsRsPopA.csv")
      total_population_2001 <- read.csv(filename)
    #drop ID column
      total_population_2001$grid_ID <- NULL  
  #2011      
    #filename & read in
      filename <- paste0("output/total-population/2011/lookup_2011_Total_Population_URPopAll.csv")
      total_population_2011 <- read.csv(filename)
    #drop ID column
      total_population_2011$grid_ID <- NULL  

#CBind together
  z_scores <- cbind(townsend_z_1971,townsend_z_2001,townsend_z_2001,townsend_z_2001,townsend_z_2011)
    colnames(z_scores) <- c("townsend_z_1971", "townsend_z_2001", "townsend_z_2001", "townsend_z_2001","townsend_z_2011")
  y1971 <- cbind(no_car_van_pc_1971, non_own_occ_pc_1971, overcrowded_pc_1971, unemployed_pc_1971)
    colnames(y1971) <- c("no_car_van_pc_1971", "non_own_occ_pc_1971", "overcrowded_pc_1971", "unemployed_pc_1971")
  y1981 <- cbind(no_car_van_pc_1981, non_own_occ_pc_1981, overcrowded_pc_1981, unemployed_pc_1981)
    colnames(y1981) <- c("no_car_van_pc_1981", "non_own_occ_pc_1981", "overcrowded_pc_1981", "unemployed_pc_1981")
  y1991 <- cbind(no_car_van_pc_1991, non_own_occ_pc_1991, overcrowded_pc_1991, unemployed_pc_1991)
    colnames(y1991) <- c("no_car_van_pc_1991", "non_own_occ_pc_1991", "overcrowded_pc_1991", "unemployed_pc_1991")
  y2001 <- cbind(no_car_van_pc_2001, non_own_occ_pc_2001, overcrowded_pc_2001, unemployed_pc_2001)
    colnames(y2001) <- c("no_car_van_pc_2001", "non_own_occ_pc_2001", "overcrowded_pc_2001", "unemployed_pc_2001")
  y2011 <- cbind(no_car_van_pc_2011, non_own_occ_pc_2011, overcrowded_pc_2011, unemployed_pc_2011)
    colnames(y2011) <- c("no_car_van_pc_2011", "non_own_occ_pc_2011", "overcrowded_pc_2011", "unemployed_pc_2011")
  total_pop <- cbind(total_population_1971,total_population_1981,total_population_1991,total_population_2001,total_population_2011)  
    colnames(total_pop) <- c("total_population_1971","total_population_1981","total_population_1991","total_population_2001","total_population_2011")        
  output <- cbind(grid_ID, total_pop, z_scores, y1971, y1981, y1991, y2001, y2011)  

  
#write CSV & CSVT
  #write csv file
    #setup filename
      filename <- paste0("townsend/summary_stats.csv")
    #write CSV file
      write.csv(output, filename, row.names = FALSE)
  #setup CSVT file
    #setup filename
      filename <- paste0("townsend/summary_stats.csvt")
    #print info & write file
      cat(paste0("String,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real,Real"), file = filename, sep = "\n")
      