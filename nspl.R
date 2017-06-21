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
source('funcs.R')

overwrite=TRUE

library(dtplyr)
library(zoo)
library(spatstat) # Required for owin
library(sp)       # Required for KDE process
require(rgdal)    # Required for readOGR to get around issue with sf and running KDE
library(sf)       # Replaces sp (usually) and does away with need for several older libs (sf == production)

# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
raw.file  = 'NSPL_FEB_2017_UK.csv'
raw.path  = c(paths$nspl,'NSPL_FEB_2017_UK','Data')

# Load the data using fread from data.table package
# (whichi is no longer explosed directly using dtplyr)
dt = data.table::fread(get.path(raw.path,raw.file))

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

# Need to reproject NI (it's in EPSG:29901)
# into EPSG:27700
dt.ni    <- subset(dt, ctry=='Northern Ireland')
dt.ni.sf <- st_as_sf(dt.ni, coords=c("oseast1m","osnrth1m"), crs=29901, agr = "constant")
t <- st_coordinates(st_transform(dt.ni.sf, 27700))
dt.ni$oseast1m = t[,1]
dt.ni$osnrth1m = t[,2]

# And update the data.table
data.table::setkey(dt, pcds)
data.table::setkey(dt.ni, pcds)
dt[dt.ni, oseast1m := i.oseast1m ]
dt[dt.ni, osnrth1m := i.osnrth1m ]
rm(t,dt.ni,dt.ni.sf)

# Use the region-buffered shape to select postcodes falling 
# within the buffered boundary at each time-step for our
# analysis
dt.sf = st_as_sf(dt, coords=c("oseast1m","osnrth1m"), crs=27700, agr = "constant")

# Now process the sub-regions
for (r in r.iter) {
  
  params = set.params(r)
  
  cat(paste("\n","======================\n","Processing data for:", params$display.nm,"\n"))
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  rb.shp <- buffer.region(params)
  
  # Save the output of st_within and then 
  # convert that to a logical vector using
  # sapply and the .flatten function
  cat("  Selecting postcodes falling within regional buffer.\n")
  is.within <- st_within(dt.df, rb.shp) %>% lengths()
  dt.region <- subset(dt, is.within==1)
  
  # Note: No viable data from 1971
  for (y in c(1981, 1991, 2001, 2011)) {
    region.y.fn = get.path(paths$nspl, get.file(t="{file.nm}_*_NSPL.shp",y))
    if (!file.exists(region.y.fn) & overwrite==FALSE) {
      cat("    Skipping since output file already exists:","\n","        ",region.y.fn,"\n")
    } else {
      # Census Day is normally late-March or early-April
      y.as_date = as.Date(paste(c(y,'03','15'),collapse="-"))
      # We could do this in one go, but it's more legible not to
      dt.region.y <- subset(dt.region, dt.region$dointr <= y.as_date)
      dt.region.y <- subset(dt.region.y, (is.na(dt.region.y$doterm) | dt.region.y$doterm > y.as_date))
      
      ########
      # Useful diagnostics about active postcodes at
      # same northing and easting
      
      # Can't use signif since we have numbers ranging
      # from 100s to 100,000s. 
      dt.region.y$oseast10m = round(dt.region.y$oseast1m/10)*10
      dt.region.y$osnrth10m = round(dt.region.y$osnrth1m/10)*10
      
      # How many are exact matches
      test = dt.region.y %>% 
        dplyr::group_by_(.dots=c("oseast1m","osnrth1m")) %>% 
        dplyr::summarize(n=n())
      test = test[test$n > 1, ]
      
      # How many are near matches
      test2 = dt.region.y %>% 
        dplyr::group_by_(.dots=c("oseast10m","osnrth10m")) %>% 
        dplyr::summarize(n=n())
      test2 = test2[test2$n > 1, ]
      
      cat("Diagnostics for:",r,"in year",y,"\n")
      cat("    Total active postcodes:",dim(dt.region.y)[1],"\n")
      cat("    Postcodes at same location:",sum(test$n),"(1m resolution)\n")
      cat("    Postcodes at same location:",sum(test2$n),"(10m resolution)\n")
      
      dt.region.y.sf <- st_as_sf(dt.region.y, coords = c("oseast1m","osnrth1m"), crs=27700, agr = "constant")
      st_write(dt.region.y.sf, region.y.fn, delete_layer=TRUE, quiet=TRUE)
      #plot(dt.region.sf)
    }
  }
}

r = 'Wales'
y = 1991
# Kriging and KDE
for (r in r.iter) {
  params = set.params(r)
  
  cat("\n","======================\n","Kriging:", params$display.nm,"\n")
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  rb.shp <- buffer.region(params)
  
  # This bit is a kludge to get around a problem that I 
  # encountered with converting directly from sf objects
  # to SpatialPolygons -- owin() refused to work with the
  # converted data (complained about missing 'W' weights 
  # vector). Writing this data out and then reading it back
  # in via OGR appears to work without a hitch. As best I 
  # can tell from investigation the issue has something to 
  # do with holes; however, the examples I found in which 
  # someone had resolved this via a function didn't work 
  # for me (and the performance was crap anyway) so the 
  # issue became pointlessly complex to resolve. Some other
  # time perhaps.
  fn = 'region.tmp.shp'            # Makes it easy to tidy up
  delete.shp(fn)                   # Check doesn't exist already
  st_write(rb.shp, fn, quiet=TRUE) # Write it out
  r.sp   <- readOGR(fn)            # Read it back i
  w      <- as.owin(r.sp)          # Window for ppp below
  delete.shp(fn)                   # And tidy up
  
  for (y in c(1981, 1991, 2001, 2011)) {
    cat("    ","Reading shape data for year:", y,"\n")
    region.y.fn   <- get.path(paths$nspl, get.file(t="{file.nm}_*_NSPL.shp",y))
    region.k.path <- get.path(paths$nspl, get.file(t="{file.nm}_*_NSPL_Kriged.shp",y))
    dt.region     <- st_read(region.y.fn, quiet=TRUE)
    
    # Extract postcode points from the sf object
    pts <- st_coordinates(dt.region)
    
    # Jitter to avoid two postcodes sitting on top of each other
    p <- ppp(jitter(pts[,1], amount=1), jitter(pts[,2], amount=1), window=w)
    
    # Possibly: https://github.com/samuelbosch/blogbits/blob/master/kernel_density/splancs_kernel_density.R
    K1 <- density(p, sigma=1500, bw="SJ", kernel="epanechnikov")
    plot(K1, main=NULL)
    #contour(K1, add=TRUE)
  }
}

# Now create the Voronoi
for (r in r.iter) {
  
  params = set.params(r)
  
  cat("\n","======================\n","Creating Voronoi Polygons for:", params$display.nm,"\n")
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  rb.shp <- buffer.region(params)
  
  for (y in c(1981, 1991, 2001, 2011)) {
    cat("    ","Reading shape data for year:", y,"\n")
    region.y.fn <- get.path(paths$nspl, get.file(t="{file.nm}_*_NSPL.shp",y))
    region.v.fn <- get.path(paths$voronoi, get.file(t="{file.nm}_*_NSPL_Voronoi.shp",y))
    dt.region     <- st_read(region.y.fn, quiet=TRUE)
    dt.region     <- dt.region %>% st_set_crs(NA) %>% st_set_crs(27700)
    
    if (st_crs(rb.shp)$epsg != st_crs(dt.region)$epsg) {
      cat(paste(rep("=",25),collapse="="), "\n")
      cat(paste(rep("=",25),collapse="="), "\n")
      print("The EPSG values don't match for the two files!")
      cat(paste(rep("=",25),collapse="="), "\n")
      cat(paste(rep("=",25),collapse="="), "\n")
    }
    
    dt.multi      <- st_multipoint(st_coordinates( st_geometry(dt.region) ))
    rb.poly       <- st_geometry(rb.shp)
    dt.v          <- st_sfc(st_voronoi(dt.multi, st_sfc(rb.poly), dTolerance=0.0)) # Cropping doesn't seem to work...
    dt.v          <- dt.v %>% st_set_crs(27700) %>% st_cast()
    # Now need to join postcodes back on to
    # the Voronoi polygons
    st_write(dt.v, region.v.fn, delete_layer=TRUE, quiet=TRUE)
    rm(dt.v, dt.region, region.v.fn, region.y.fn, rb.poly, dt.multi)
  }
}

cat("Done processing NSPL data...\n")