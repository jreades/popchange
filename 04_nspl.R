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
#rm(list = ls())
source('funcs.R')
source('config.R')

params = set.params(r)
cat("\n","======================\n","04:NSPL (", params$display.nm,")\n")

# Load the data using fread from data.table package
# (whichi is no longer explosed directly using dtplyr)
dt = data.table::fread(get.path(paths$ons.src,'NSPL_MAY_2017_UK.csv'))

cat(paste("NSPL file dimensions:",dim(dt)[1],"rows,",dim(dt)[2],"cols"),"\n")

######################################################
######################################################
# Step 1: Clean and process the raw NSPL data file
#         so that we have something a little more
#         manageable. We are also going to try to 
#         infer some information about the area from
#         the various indicators provided for each 
#         postcode (RU11 and OAC11; BUA11 might be
#         useful too, but is harder to use).
######################################################
######################################################
# Columns we don't need:
# =====================
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
# Fields that we want to keep:
# ===========================
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
rm(to.drop)

# Stick fake day-of-month on end of dates to avoid
# issues with as.yearmon (which I couldn't parse)
dt$introduced <- as.Date(paste(dt$dointr,'01',sep=""), format="%Y%m%d")
dt$terminated <- as.Date(paste(dt$doterm,'01',sep=""), format="%Y%m%d")

# Convert usertype to factor
dt$usertype <- factor(dt$usertype, labels=c('Small','Large'))

# Convert grid info to numeric
dt$oseast1m <- as.numeric(dt$oseast1m)
dt$osnrth1m <- as.numeric(dt$osnrth1m)
dt$osgrdind <- as.numeric(dt$osgrdind)

# Convert country, GoR and Park to factor
dt$country <- factor(dt$ctry, levels=c('E92000001','L93000001','M83000003','N92000002','S92000003','W92000004'), labels=c('England','Channel Islands','Isle of Man','Northern Ireland','Scotland','Wales'), exclude=c(""))
dt$region  <- factor(dt$gor, levels=c('E12000001','E12000002','E12000003','E12000004','E12000005','E12000006','E12000007','E12000008','E12000009','L99999999','M99999999','N99999999','S99999999','W99999999'), labels=c('North East','North West','Yorkshire and The Humber','East Midlands','West Midlands','East of England','London','South East','South est','Channel Islands','Isle of Man','Northern Ireland','Scotland','Wales'), exclude=c(""))
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
dt <- dt[ dt$country %nin% c('Channel Islands','Isle of Man') & ! is.na(dt$country), ]
# These ones don't have a useable location
dt <- dt[ !dt$osgrdind==9, ]
# And these ones are 'large' users of postcodes so
# presumably not residential
dt <- dt[ !dt$usertype=='Large', ]

# Should be on the order of 1.88 million rows and 22 columns
cat(paste("NSPL final dimensions:",dim(dt)[1],"rows,",dim(dt)[2],"cols"),"\n")

# Need to separate NI (it's in EPSG:29901)
dt.ni    <- subset(dt, country=='Northern Ireland')
dt.ni.sf <- st_as_sf(dt.ni, coords=c("oseast1m","osnrth1m"), crs=crs.ni, agr="constant")

dt       <- subset(dt, country!='Northern Ireland')
dt.sf    <- st_as_sf(dt, coords=c("oseast1m","osnrth1m"), crs=crs.gb, agr="constant")

# Tidy up
rm(dt.ni, dt)

######################################################
######################################################
# Step 2: Create CSV files for each Census time period
#         and each region so that we can load only what
#         we need in subsequent processing.
######################################################
######################################################
  
# Region-Buffered shape
rb.shp <- buffer.region(params)

# Save the output of st_within and then 
# convert that to a logical vector using
# lengths()
cat("  Selecting postcodes falling within regional buffer.\n")
if (r=='Northern Ireland') {
  dt.region <- as.data.table(dt.ni.sf)
  dt.region$oseast1m = st_coordinates(dt.region$geometry)[ , 'X']
  dt.region$osnrth1m = st_coordinates(dt.region$geometry)[ , 'Y']
  dt.region$geometry <- NULL
} else {
  is.within <- st_within(dt.sf, rb.shp) %>% lengths()
  dt.region <- subset(dt, is.within==1)
  rm(is.within)
}

# Note: No viable data from 1971
#       No viable NI data from 1981
for (y in census.years) {
  region.y.fn = get.path(paths$nspl, get.file(t="{file.nm}-NSPL-*.csv",y))
  if (file.exists(region.y.fn)) {
    cat("    Skipping since output file already exists:","\n","        ",region.y.fn,"\n")
  } else {
    # Census Day is normally late-March or early-April
    y.as_date = as.Date(paste(c(y,'03','15'),collapse="-"))
    # We could do this in one go, but it's more legible not to
    dt.region.y <- subset(dt.region, dt.region$introduced <= y.as_date)
    dt.region.y <- subset(dt.region.y, (is.na(dt.region.y$terminated) | dt.region.y$terminated > y.as_date))
    
    if (nrow(dt.region.y) > 0) {
      
      ########
      # Useful diagnostics about active postcodes at
      # same northing and easting
      
      # There are 2011 Rural/Urban indicators
      if (sum(is.na(dt.region.y$ru11ind))/nrow(dt.region.y) < 1.0) {
        dt.region.y <- dt.region.y %>% 
          mutate( urban = ifelse( ru11ind %in% c('A1','B1','C1','1','2'), 1, 0) )
        # Otherwise fall back on OAC 2011
      } else {
        dt.region.y <- dt.region.y %>% 
          mutate( urban = ifelse( grepl('^[23457][A-Z]', oac11, perl=TRUE), 1, 0))
      }
      
      write.csv(subset(dt.region.y, select=c('pcds','oseast1m','osnrth1m','osgrdind','oa11','ru11ind','oac11','urban','introduced','terminated','country','region')), file=region.y.fn, row.names=FALSE)
    }
    rm(y.as_date)
  }
}
rm(y,region.y.fn,dt.region.y,dt.region)
rm(dt.sf,dt.ni.sf)

######################################################
######################################################
# Step 3: Now link to the grid and aggregate into 
#         columns for hi- and lo-rise development
#         based on the precision of the coordinate
#         overlaps.
######################################################
######################################################
for (y in census.years) {
  
  if (file.exists(get.path(paths$nspl, get.file(t="{file.nm}-NSPL-*.csv",y)))) {
    
    dt = data.table::fread(get.path(paths$nspl, get.file(t="{file.nm}-NSPL-*.csv",y)))
    
    # Round off any sub-1m resolution info as seems to be a 
    # problem for the sf library or GDAL.
    # Note cast to data frame -- seems to be triggered
    # by this bug: https://github.com/hadley/dtplyr/issues/51
    dt = as.data.frame(dt) %>% 
      dplyr::mutate_at(c("oseast1m", "osnrth1m"), funs(round(.,0))) %>%
      dplyr::mutate(oseast10m=round(oseast1m,-1)) %>% 
      dplyr::mutate(osnrth10m=round(osnrth1m,-1))
    
    dupes1m = dt %>% 
      dplyr::filter(osgrdind <= 4) %>%
      dplyr::filter(urban == 1) %>%
      dplyr::group_by_(.dots=c("oseast1m","osnrth1m")) %>% 
      dplyr::summarize(n=n())
    dupes1m = dupes1m %>% filter(n > 1) %>% mutate(hi_dense=1)
    
    # How many are near matches
    dupes10m = dt %>% 
      dplyr::filter(osgrdind <= 4) %>%
      dplyr::filter(urban == 1) %>% 
      dplyr::group_by_(.dots=c("oseast10m","osnrth10m")) %>% 
      dplyr::summarize(n=n())
    dupes10m = dupes10m %>% filter(n > 1) %>% mutate(hi_dense=1)
    
    # Now set a flag that we can use
    # when joining to the grid
    dt.categorised = dt %>% 
      left_join(dupes1m, by=c('oseast1m','osnrth1m')) %>%
      select( -n ) %>% 
      mutate( hi_dense = ifelse( is.na(hi_dense), 0, 1) )
    
    cat("Diagnostics for:",params$display.nm,"in year",y,"\n")
    cat("    Have filtered for GridLink indicator <= 4","\n")
    cat("    Total active postcodes:",nrow(dt),"\n")
    cat("    Postcodes at same location:",sum(dupes1m$n),"(1m resolution)\n")
    cat("    Postcodes at same location:",sum(dupes10m$n),"(10m resolution)\n")
    cat("    Postcodes flagged as high-density:",sum(dt.categorised$hi_dense==1),"(1m resolution)\n")
    
    write.csv(dt.categorised, file=get.path(paths$int, get.file(t="{file.nm}-{g.resolution}m-*-Points.csv",'NSPL',y)), row.names=FALSE)
    
    target.crs = crs.gb
    if (r=='Northern Ireland') {
      target.crs = crs.ni
    }
    
    cat("  Loading grid with resolution",g.resolution,"m.","\n")
    grd <- st_read(get.path(paths$grid, get.file(t="{file.nm}-{g.resolution}m-Grid.shp")), quiet=TRUE)
    grd <- grd %>% st_set_crs(NA) %>% st_set_crs(target.crs)
    
    dt.categorised.sf <- st_as_sf(dt.categorised, coords=c("oseast1m","osnrth1m"), crs=target.crs, agr='identity')
    
    # We can drop non-matching rows as we're going to 
    # output a CSV file to join back on to the grid
    # later.
    grid.join = grd %>% st_join(dt.categorised.sf, left=FALSE) %>% group_by(id) %>% summarise(hi_density=sum(hi_dense), total=n())
    grid.join$lo_density = grid.join$total - grid.join$hi_density
    
    write.csv(st_set_geometry(grid.join, NULL), file=get.path(paths$int, get.file(t="{file.nm}-{g.resolution}m-*-Grid.csv",'NSPL',y)), row.names=FALSE)
    rm(grid.join)
  } else {
    cat("Skipping grid-linking for",params$display.nm,"as no data for year",y,"\n")
  }
}

######################################################
######################################################
# Step 4: Things that we could now do to help estimate
#         population locations. NOT IMPLEMENTED YET.
######################################################
######################################################
# Kriging and KDE
# cat("\n","======================\n","Kriging:", params$display.nm,"\n")
# 
# # This bit is a kludge to get around a problem that I 
# # encountered with converting directly from sf objects
# # to SpatialPolygons -- owin() refused to work with the
# # converted data (complained about missing 'W' weights 
# # vector). Writing this data out and then reading it back
# # in via OGR appears to work without a hitch. As best I 
# # can tell from investigation the issue has something to 
# # do with holes; however, the examples I found in which 
# # someone had resolved this via a function didn't work 
# # for me (and the performance was crap anyway) so the 
# # issue became pointlessly complex to resolve. Some other
# # time perhaps.
# fn = 'region.tmp.shp'            # Makes it easy to tidy up
# delete.shp(fn)                   # Check doesn't exist already
# st_write(rb.shp, fn, quiet=TRUE) # Write it out
# r.sp   <- readOGR(fn)            # Read it back i
# w      <- as.owin(r.sp)          # Window for ppp below
# delete.shp(fn)                   # And tidy up
# 
# for (y in c(1981, 1991, 2001, 2011)) {
#   cat("    ","Reading shape data for year:", y,"\n")
#   region.y.fn   <- get.path(paths$nspl, get.file(t="{file.nm}_*_NSPL.shp",y))
#   region.k.path <- get.path(paths$nspl, get.file(t="{file.nm}_*_NSPL_Kriged.shp",y))
#   dt.region     <- st_read(region.y.fn, quiet=TRUE)
#   
#   # Extract postcode points from the sf object
#   pts <- st_coordinates(dt.region)
#   
#   # Jitter to avoid two postcodes sitting on top of each other
#   p <- ppp(jitter(pts[,1], amount=1), jitter(pts[,2], amount=1), window=w)
#   
#   # Possibly: https://github.com/samuelbosch/blogbits/blob/master/kernel_density/splancs_kernel_density.R
#   K1 <- density(p, sigma=1500, bw="SJ", kernel="epanechnikov")
#   plot(K1, main=NULL)
#   #contour(K1, add=TRUE)
# }
# 
# # Now create the Voronoi
#   
# cat("\n","======================\n","Creating Voronoi Polygons for:", params$display.nm,"\n")
# 
# for (y in c(1981, 1991, 2001, 2011)) {
#   cat("    ","Reading shape data for year:", y,"\n")
#   
#   target.crs = crs.gb
#   if (r =='Northern Ireland') {
#     target.crs = crs.ni
#   }
#   
#   region.y.fn <- get.path(paths$nspl, get.file(t="{file.nm}_*_NSPL.shp",y))
#   region.v.fn <- get.path(paths$voronoi, get.file(t="{file.nm}_*_NSPL_Voronoi.shp",y))
#   dt.region     <- st_read(region.y.fn, quiet=TRUE)
#   dt.region     <- dt.region %>% st_set_crs(NA) %>% st_set_crs(target.crs)
#   
#   if (st_crs(rb.shp)$epsg != st_crs(dt.region)$epsg) {
#     cat(paste(rep("=",25),collapse="="), "\n")
#     cat(paste(rep("=",25),collapse="="), "\n")
#     print("The EPSG values don't match for the two files!")
#     cat(paste(rep("=",25),collapse="="), "\n")
#     cat(paste(rep("=",25),collapse="="), "\n")
#   }
#   
#   dt.multi      <- st_multipoint(st_coordinates( st_geometry(dt.region) ))
#   rb.poly       <- st_geometry(rb.shp)
#   dt.v          <- st_sfc(st_voronoi(dt.multi, st_sfc(rb.poly), dTolerance=0.0)) # Cropping doesn't seem to work...
#   dt.v          <- dt.v %>% st_set_crs(target.crs) %>% st_cast()
#   # Now need to join postcodes back on to
#   # the Voronoi polygons
#   st_write(dt.v, region.v.fn, delete_layer=TRUE, quiet=TRUE)
#   rm(dt.v, dt.region, region.v.fn, region.y.fn, rb.poly, dt.multi)
# }

cat("  Done processing NSPL data...\n")