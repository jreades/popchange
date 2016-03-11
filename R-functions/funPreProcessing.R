#Function to preprocess data to set columns in oa2011_weigthed and merge lake and woodland landuse
PreProcessing <- function(oa2011_weighted, longLog = FALSE){
  #add column with a value of 1 to each OA, which is then allocated proportionally
    oa2011_weighted@data$population <- 1
  #remove columns
    oa2011_weighted <- oa2011_weighted[,-(1:2)]
    oa2011_weighted <- oa2011_weighted[,-(2:5)]
    oa2011_weighted <- oa2011_weighted[,-(3:4)]
  #check values
    as.data.frame(table(oa2011_weighted@data$landuse))
  #rename columns
    names(oa2011_weighted@data)[names(oa2011_weighted@data) == 'OA11CD'] <- 'OA'
    names(oa2011_weighted@data)[names(oa2011_weighted@data) == 'landuse'] <- 'landuse_1'
  #setup fields
    #combine columns to have one landuse column
      oa2011_weighted@data$landuse <- NA
    #using term 'lakewood' to be either woodland or lake
      oa2011_weighted@data[which(oa2011_weighted@data$landuse_1 == "woodland"),]$landuse <- "lakewood"
    #set lakes as being the same as woodland
      oa2011_weighted@data[which(oa2011_weighted@data$landuse_1 == "lake"),]$landuse <- "lakewood"
      oa2011_weighted@data[which(oa2011_weighted@data$landuse_1 == "urban"),]$landuse <- "urban"
    #remove extra columns
    oa2011_weighted@data$landuse_1 <- NULL
  #show table
    head(oa2011_weighted@data)
  #show number of each OA
    head(as.data.frame(table(oa2011_weighted@data$OA)))
  #show number of each landuse
    as.data.frame(table(oa2011_weighted@data$landuse))
  #return data
    return(oa2011_weighted)
}