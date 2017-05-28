# Where to find ogr2ogr -- this is the OSX location when installed
# from the fantastic KyngChaos web site
ogr.lib = '/Library/Frameworks/GDAL.framework/Programs/ogr2ogr'

# The strings here should match the Geofabrik OSM file name 
# (allowing for %>% ucfirst these are England, Scotland, Wales).
r.countries  <- c('England', 'Scotland', 'Wales')

# For England there is so much data that it makes sense 
# to break it down into regions. Even if our approach 
# below is a little inefficient (the bounding box for
# the South East actually includes all of London!) it 
# reduces the overall processing power required to 
# achieve the outputs and also theoretically enables
# it to be parallelised. We do not need to do this for
# Scotland and Wales, although if we dove below the GoR
# scale then we could use the district boundaries to 
# speed this up still further (although at the cost of 
# many more outputs to track and manage).
r.regions    <- c('London','North West','North East','Yorkshire and The Humber','East Midlands','West Midlands','East of England','South East','South West') # Applies to England only / NA for Scotland and Wales at this time

r.iter       <- c(paste(r.countries[1],r.regions),r.countries[2:length(r.countries)])

r.buffer     <- 10000                      # Buffer to draw around region to filter (in metres)
r.simplify   <- 500
osm.buffer   <- 5.0                        # Buffer to use around OSM features to help avoid splinters and holes (in metres)
osm.simplify <- 10.0                       # Simplify distance to use on OSM features to help speed up calculations (in metres)

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

# We need to work out xmin and ymin such that we get a fairly consistent
# output no matter what the user specifies -- in other words, we don't 
# want grids starting at an Easting of 519,728 so it makes sense to round
# down (to be below and to the right) to the nearest... 10k?
g.resolution <- 500                        # Grid resolution (in metres)
g.anchor     <- 10000                      # Anchor grid min/max x and y at nearest... (in metres)

# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
os.path = c(getwd(),'no-sync','OS')
osm.path = c(getwd(),'no-sync','OSM')
nspl.path = c(getwd(),'no-sync','NSPL')

out.path = c(getwd(),'no-sync','grid')
out.path = c(getwd(),'no-sync','processed')

.simpleCap <- function(x) {
  s <- strsplit(tolower(x), "[_ ]")[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2),
        sep = "", collapse = "_")
}