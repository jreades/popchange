#Read in 1971 
OA_attributes <- read.csv("data/1971/attributes/sas08-country-of-birth/1971_sas08_unmerged.csv")  

#Read in lookup file
OA_attributes_lookup <- read.csv("data/1971/attributes/ED71_ED81lookupF.csv")  

#merge data
OA_attributes_merged <- merge(OA_attributes,OA_attributes_lookup,by.x="GeographyCode",by.y="ED71code") 

#copy new geography code to first field
OA_attributes_merged$GeographyCode <- OA_attributes_merged$ED81mergeLINK

#remove columns
OA_attributes_merged$OPCS.Code <- NULL
OA_attributes_merged$ED81old <- NULL
OA_attributes_merged$ED81mergeLINK <- NULL

#save csv
write.csv(OA_attributes_merged, file= "data/1971/attributes/1971-OA-attributes-sas08.csv", row.names = FALSE)  
