rm(list = ls())
#########################################
# Process the NSPL (National Statistics Postcode
# Lookup) data into several outputs that can be
# aligned with the decennial Census. So we only 
# want the density step to use the postcodes 
# available at that time, not the postcodes as 
# they are now. Because postcodes can be re-used
# we can't guarantee that this is 100% accurate
# but, again, it's a reasonable estimate based on
# available testing and research.
#
########################################
library(data.table)
library(DBI)
library(sf)  # Replaces sp and does away with need for several older libs (sf == production)

# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
nspl.path = c(getwd(),'no-sync','NSPL')
raw.file  = 'NSPL_FEB_2017_UK.csv'
raw.path  = c(nspl.path,'NSPL_FEB_2017_UK','Data')

dt = fread(paste(c(raw.path,raw.file), collapse="/"))

cat(paste("NSPL file dimensions:",dim(dt)[1],"rows,",dim(dt)[2],"cols"),"\n")

# Columns we don't need:
# - pcd: 7 character version of postcode (3rd and 4th chars may be blank as inward code is right-aligned)
# - pcd2: 8 character version of postcode (3rd and 4th chars may be blank as inward-code is right-aligned and 5th character always blank)
# - cty: county 
# - laua: local authority / unitary authority
# - ward: electoral ward 
# - hlthau: health authority
# - hro: strategic health authority for each postcode in England
# - pcon: Parliamentary constituency
# - eer: European electoral region
# - teclec: learning and skills areas
# - ttwa: travel-to-work areas
# - pct: primary care trust
# - nuts: national LAU2-equivalent
# - lsoa11: lower super output areas (2011 Census)
# - msoa11: middle super output areas (2011 Census)
# - wz11: Census workplace zones
# - ccg: clinical commissioning group
# - bua11: built-up area
# - lep1: local enterprise partnership
# - lep2: local enterprise partnership
# - pfa: police force area
# - imd: index of multiple deprivation
#
# Fields that we want to keep and rationale for keeping them:
# - pcds: variable length postcode version (always one space between outward [first half] and inward [second half] of postcode)
# - dointr: date of introduction in yyyymm format (filter out postcodes that didn't yet exist at time of Census)
# - doterm: date of termination in yyyymm format (filter out postcodes that no longer existed at time of Census)
# - usertype: postcode user type (0 = small user; 1 = large user) [needs investigation / may want to filter out type 1 for residential densities]
# - oseast1m: OS Easting reference (standard for EPSG:27700)
# - osnrth1m: OS Northing reference (standard for EPSG:27700)
# - osgrdind: OS positional quality indicator (1=within building closest to postcode mean; 2=same as 1 but by visual inspection in Scotland; 3=approx to within 50m; 4=postcode unit mean not snapped to building; 5=imputed by reference to surrouding postcode grid refs; 6=postcode sector mean [usually PO boxes]; 8=terminated prior to Gridlink so based on last know ONS postcode grid ref; 9=no grid ref available)
# - oa11: output area 2011 Census (targeted match level for modelling)
# - ctry: country (useful as a quick filter)
# - gor: government office for regions reference (useful as a quick filter)
# - park: national park [needs investigation]
# - buasd11: built-up area sub-division [needs investigation]
# - ru11ind: 2011 Census rural-urban classifcation [needs investigation]
# - oac11: infer residential information from Output Area Classification [needs investigation]
# - lat: latitutde to 6 decimal places
# - long: longitude to 6 decimal places
###################
to.drop = c('pcd','pcd2','cty','laua','ward','hlthau','hro','pcon','eer','teclec','ttwa','pct','nuts','lsoa11','msoa11','wz11','ccg','bua','lep1','lep2','pfa','imd')
dt[,c(to.drop):=NULL]

