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
source('config.R')

library(data.table)
library(ggplot2)
library(zoo)
library(DBI)
library(sf)  # Replaces sp and does away with need for several older libs (sf == production)

# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
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
to.drop = c('pcd','pcd2','cty','laua','ward','hlthau','hro','pcon','eer','teclec','ttwa','pct','nuts','lsoa11','msoa11','wz11','ccg','bua11','buasd11','lep1','lep2','pfa','imd')
dt[,c(to.drop):=NULL]

# Convert introduction/termination to date class
dt$dointr <- as.Date(as.yearmon(dt$dointr,'%Y%m'))
dt$doterm <- as.Date(as.yearmon(dt$doterm,'%Y%m'))

# Convert usertype to factor
dt$usertype <- factor(dt$usertype, labels=c('Small','Large'))

# Convert grid info to numeric
dt$oseast1m <- as.numeric(dt$oseast1m)
dt$osnrth1m <- as.numeric(dt$osnrth1m)
dt$osgrdind <- as.numeric(dt$osgrdind)

# Convert country, GoR and Park to factor
dt$ctry <- factor(dt$ctry, levels=c('E92000001','L93000001','M83000003','N92000002','S92000003','W92000004'), labels=c('England','Channel Islands','Isle of Man','Northern Ireland','Scotland','Wales'), exclude=c(""))
dt$gor  <- factor(dt$gor, levels=c('E12000001','E12000002','E12000003','E12000004','E12000005','E12000006','E12000007','E12000008','E12000009','L99999999','M99999999','N99999999','S99999999','W99999999'), labels=c('North East','North West','Yorkshire and The Humber','East Midlands','West Midlands','East of England','London','South East','South est','Channel Islands','Isle of Man','Northern Ireland','Scotland','Wales'), exclude=c(""))
dt$park <- factor(dt$park, exclude=c(""))

# Convert Rural/Urban indicator to factor
dt$ru11ind <- factor(dt$ru11ind, exclude=c(""))

# There's not much from pre-1980 that is reliable
# as that's connected to the introduction of GridLink
# ggplot(dt, aes(x=dointr)) + 
#   geom_bar(stat="count") + 
#   ggtitle("Date of Introduction") + 
#   ylab("Count") + 
#   scale_x_date(date_breaks = "1 year", date_labels = "%Y") + 
#   theme(axis.text.x = element_text(angle = 90, hjust = 1))
# ggplot(dt, aes(x=doterm)) + 
#   geom_bar(stat="count") + 
#   ggtitle("Date of Termination") + 
#   ylab("Count") + 
#   scale_x_date(date_breaks = "1 year", date_labels = "%Y") + 
#   theme(axis.text.x = element_text(angle = 90, hjust = 1))

# We currently only process data for the UK
# and drop it for Channel Islands & Isle of Man
dt <- dt[ !dt$ctry %in% c('Channel Islands','Isle of Man'), ]
# These ones don't have a useable location
dt <- dt[ !dt$osgrdind==9, ]
# And these ones are 'large' users of postcodes so
# presumably not residential
dt <- dt[ !dt$usertype=='Large', ]

cat(paste("NSPL final dimensions:",dim(dt)[1],"rows,",dim(dt)[2],"cols"),"\n")

for (r in r.iter) {
  the.label <- .simpleCap(r)
  the.country <- strsplit(r, " ")[[1]][1]
  the.region <- paste(strsplit(r, " ")[[1]][-1], collapse=" ")
  
  cat(paste("\n","======================\n","Processing data for:", the.country,"\n"))
  
  if (length(the.region) == 0 | the.region=="") { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(paste(c(os.path, "CTRY_DEC_2011_GB_BGC.shp"), collapse="/"), stringsAsFactors=T)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$CTRY11NM==the.country,]
    
  } else { # Filtering for regions
    r.filter.name <- sub("^[^ ]+ ","",r, perl=TRUE)
    cat(paste("  Processing internal GoR region:", the.region,"\n")) 
    
    shp <- st_read(paste(c(os.path, "Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"), collapse="/"), stringsAsFactors=T)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Next the shapefile has to be converted to a dataframe for use in ggplot2
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- shp[shp$FILE_NAME==r.filter,]
    # Use this for filtering on GOR regions:
    r.shp <- shp[shp$rgn16nm==the.region,]
  }
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  rb.shp <- st_buffer(st_simplify(r.shp, r.simplify), r.buffer)
  
  # Use the region-buffered shape to select postcodes falling 
  # within the buffered boundary at each time-step for our
  # analysis
  dt.sf = st_as_sf(dt, coords = c("oseast1m","osnrth1m"), crs=27700, agr = "constant")
  
  .flatten <- function(x) {
    if (length(x) == 0) { 
      FALSE
    } else { 
      TRUE
    }
  }
  # Save the output of st_within and then 
  # convert that to a logical vector using
  # sapply and the .flatten function
  cat("  Selecting postcodes falling within regional buffer.")
  is.within    <- st_within(dt.sf, rb.shp)
  dt.region    <- subset(dt, sapply(is.within, .flatten))
  
  # Note: No viable data from 1971
  overwrite=TRUE
  for (y in c(1981, 1991, 2001, 2011)) {
    cat(paste("    Processing postcodes available in year:",y),"\n")
    region.y.path = paste(c(nspl.path, paste(c(the.label,y,"NSPL.shp"),collapse="_")), collapse="/")
    if (file.exists(region.y.path) & overwrite==FALSE) {
      cat("    Skipping since output file already exists:\n        ",region.y.path,"\n")
    } else {
      # Census Day is normally late-March or early-April
      y.as_date = as.Date(paste(c(y,'03','15'),collapse="-"))
      # We could do this in one go, but it's more legible not to
      dt.region.y <- subset(dt.region, dt.region$dointr <= y.as_date)
      dt.region.y <- subset(dt.region.y, (is.na(dt.region.y$doterm) | dt.region.y$doterm > y.as_date))
      cat("    Have",dim(dt.region.y)[1],"active postcodes in",y,"\n")
      dt.region.y.sf <- st_as_sf(dt.region.y, coords = c("oseast1m","osnrth1m"), crs=27700, agr = "constant")
      st_write(dt.region.y.sf, region.y.path, delete_layer=TRUE)
      #plot(dt.region.sf)
    }
  }
}

cat("Done...\n")