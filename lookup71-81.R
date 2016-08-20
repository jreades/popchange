#Read in 1971
OA_attributes <- read.csv("input/1971/attributes/townsend/1971_townsend_unmerged.csv")  

#Read in lookup file
OA_attributes_lookup <- read.csv("input/1971/attributes/ED71_ED81lookupF.csv")  

#merge data
OA_attributes_merged <- merge(OA_attributes,OA_attributes_lookup,by.x="GeographyCode",by.y="ED71code") 

#view merge to check data
head(OA_attributes_merged)

#copy new geography code to first field
OA_attributes_merged$GeographyCode <- OA_attributes_merged$ED81mergeLINK

#remove columns
OA_attributes_merged$OPCS.Code <- NULL
OA_attributes_merged$ED81old <- NULL
OA_attributes_merged$ED81mergeLINK <- NULL

#view merge to check data
head(OA_attributes_merged)

#save csv
write.csv(OA_attributes_merged, file= "input/1971/attributes/1971_townsend.csv", row.names = FALSE)  
