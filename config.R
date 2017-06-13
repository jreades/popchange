# SETUP: the scripts expect the following dir
# structure -- the data directories are not 
# found in git because of the data volumes 
# associated with extracting and processing 
# OSM features.
#
# popchange/
#   no-sync/ # Don't manage content here with Git
#      OS/   # For Ordnance Survey data
#      OSM/  # For OSM data
#      land-polygons/ # Also OSM, but from different source
#      processed/     # Outputs from gridding process at national and regional levels

########## Software Configuration
# Where to find ogr2ogr -- this is the OSX location when installed
# from the fantastic KyngChaos web site
ogr.lib  = '/Library/Frameworks/GDAL.framework/Programs/ogr2ogr'
ogr.info = '/Library/Frameworks/GDAL.framework/Programs/ogrinfo'

########## Regions Configuration
# The strings here should match the Geofabrik OSM file name 
# (allowing for %>% ucfirst these are England, Scotland, Wales).
r.countries  <- c('England', 'Scotland', 'Wales', 'Northern Ireland')

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

########## Region Buffer Configuration
r.buffer       <- 5000                       # Buffer to draw around region to filter (in metres)
r.simplify     <- 500                        # Simplify the boundaries before drawing the buffer (for performance)

########## Roads Buffer Configuration
roads.buffer   <- 150                        # Buffer to draw around roads to filter (in metres)
roads.simplify <- 100                        # Simplify the roads before drawing the buffer (for performance)

########## Grid Configuration
# We need to work out xmin and ymin such that we get a fairly consistent
# output no matter what the user specifies -- in other words, we don't 
# want grids starting at an Easting of 519 or 728 so it makes sense to round
# the bounding box for the region to the nearest... 'x' km?
g.resolution   <- 250                        # Grid resolution (in metres)
g.anchor       <- 5000                       # Anchor grid min/max x and y at nearest... (in metres)

########## Data Storage Configuration
# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
os.path = c(getwd(),'no-sync','OS')
osm.path = c(getwd(),'no-sync','OSM')
nspl.path = c(getwd(),'no-sync','NSPL')
roads.path = c(getwd(),'no-sync','Roads')
grid.out.path = c(getwd(),'no-sync','grid')
out.path = c(getwd(),'no-sync','processed')

########## OSM Configuration
osm.buffer   <- 5.0                        # Buffer to use around OSM features to help avoid splinters and holes (in metres)
osm.simplify <- 10.0                       # Simplify distance to use on OSM features to help speed up calculations (in metres)

# Set up the OSM classes that we want to pull from the PBF
# file. Each of these corresponds to a column configured 
# via the osmconf.ini file. In truth, the way OSM works 
# means that these columns are not strictly enforced (so,
# for instance, common can show up in leisure too). This 
# is why we merge them all and search for all of them in 
# all of the columns that we check.
#
# Note: it would be tempting to include some major features
# like national parks in this process; however, in the UK it
# is possible to have development within a national park (e.g.
# Aviemore within Cairngorms National Park; various
# within Peak District National Park) so I have deliberately
# left this land use out of the data pull.
osm.classes = new.env()
osm.classes$natural = c('coastline', 'beach', 'bay', 'common', 'dune', 'fell', 'grass', 'grassland', 'heath', 'moor', 'mud', 'scrub', 'upland_fell', 'unimproved_grassland', 'wetland', 'water', 'wood')
osm.classes$landuse = c('airfield', 'allotments', 'brownfield', 'cemetery', 'churchyard', 'farmland', 'farmyard', 'forest', 'landfill', 'marsh', 'meadow', 'orchard', 'park', 'quarry', 'reservoir', 'runway', 'scrub', 'vineyard', 'waterway', 'greenfield', 'village_green', 'playground') 
osm.classes$leisure = c('golf', 'golf_course', 'miniature_golf', 'marina', 'nature_reserve', 'park', 'pitch', 'quad_bikes', 'recreation_ground', 'sports_field', 'track', 'water_park') 
# These are NOT NULL...
osm.classes$not_null = c('aeroway') 
# These are amenity IS NOT NULL and these are NOT IN... (i.e. all amenities except these ones are *included*)
osm.classes$amenity = c('hospice', 'nursing_home', 'retirement_home', 'student_accomodation')

# This *could* be useful in theory but doesn't seem to add much value in practice
#osm.classes$other_tags = c('%Forest%', '%Common%', '%Heath%') # Based on the Other field: "designation"=>"Swinley Forest"

# Merge all classes to deal with inconsistency in tagging
# by OSM contributors -- some have used the 'other' tag 
# instead of the 'natural' or 'landuse' ones.
osm.classes$natural = unique(c(osm.classes$natural, osm.classes$landuse, osm.classes$leisure))
osm.classes$landuse = osm.classes$natural
osm.classes$leisure = osm.classes$natural

########## Sanity check -- we only need to run this once...
if (! file.exists(paste(c(os.path, "CTRY_DEC_2011_UK_BGC.shp"), collapse="/"))) {
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat("Have you run the ni-preprocessing.R script yet?\n")
  cat("This is critical to the remaining processes!\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
}