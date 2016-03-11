#Function to print summary of data sensibly.
DataSummaryNoOverlay <- function(time, longLog = FALSE){
  #Filename
    cat("\n", "Summary for:", filename_prefix)
  #Number of OAs
    #cat("\n", "Number of OAs:",length(oa2011_weighted@data[,1]))
    #update to allow number of OAs to br read from oa_grid
  #  cat("\n", "Number of OAs:",length(unique(oa2011_grid@data$OA11CD)))
  #number of Grids
    cat("\n", "Number of non Split Grid Cells:",length(grid_m_notSplit))
  #number of regions
    cat("\n", "Number of Regions:",length(list_regions)-1)
  #Time
    for (i in 1:length(sectionTime)) {
      cat("\n", "Section", i, sectionName[i]," elapsed:", format(sectionTime[i], digits = 4, nsmall = 2, trim = TRUE), "seconds", (format(sectionTime[i]/60, digits = 4, nsmall = 2, trim = TRUE)), "min", (format(sectionTime[i]/60/60, digits = 2, nsmall = 1, trim = TRUE)), "hours")
    }
    cat("\n", "Total Time elapsed:", format(totalTime, digits = 4, nsmall = 2, trim = TRUE), "seconds", format(totalTime/60, digits = 4, nsmall = 2, trim = TRUE), "min", (format(totalTime/60/60, digits = 2, nsmall = 1, trim = TRUE)), "hours")
  #Save to log file
    filename <- paste0("output/",filename_prefix,"_log_file.txt")
    #print log info
    cat(paste0("Summary for: ", filename_prefix), file = filename, sep = "\n")
  #  cat(paste0("Number of OAs: ",length(unique(oa2011_grid@data$OA11CD))), file = filename, sep = "\n", append = TRUE)
    cat(paste0("Number of non Split Grid Cells: ",length(grid_m_notSplit)), file = filename, sep = "\n", append = TRUE)
    cat(paste0("Number of Regions: ",length(list_regions)-1), file = filename, sep = "\n", append = TRUE)
    for (i in 1:length(sectionTime)) {
      cat(paste("Section", i, sectionName[i], " elapsed: ", format(sectionTime[i], digits = 4, nsmall = 2, trim = TRUE), " seconds ", (format(sectionTime[i]/60, digits = 4, nsmall = 2, trim = TRUE)), " min ", (format(sectionTime[i]/60/60, digits = 2, nsmall = 1, trim = TRUE)), " hours "), file = filename, sep = "\n", append = TRUE)
    }
    cat(paste0("Total Time elapsed: ", format(totalTime, digits = 4, nsmall = 2, trim = TRUE), " seconds ", format(totalTime/60, digits = 4, nsmall = 2, trim = TRUE), " min ", (format(totalTime/60/60, digits = 2, nsmall = 1, trim = TRUE)), " hours "), file = filename, sep = "\n", append = TRUE)
}
    