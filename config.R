# SETUP: the setup script should be run to create the
# directory structure set out below -- the data directories 
# are not found in git because of the volumes associated
# with extracting and processing OSM features.

########## Software Configuration
# Where to find ogr2ogr -- this is the OSX location when installed
# from the fantastic KyngChaos web site
ogr.lib  = '/Library/Frameworks/GDAL.framework/Programs/ogr2ogr'
ogr.info = '/Library/Frameworks/GDAL.framework/Programs/ogrinfo'

########## Data Storage Configuration
# We assume that spatial data is stored under the current 
# working directory but in a no-sync directory since these
# files are enormous.
paths = new.env()
paths$root      = 'no-sync'
paths$os        = c(getwd(),paths$root,'os')
paths$osm       = c(getwd(),paths$root,'osm')
paths$osni      = c(getwd(),paths$root,'osni')
paths$nspl      = c(getwd(),paths$root,'nspl')
paths$roads     = c(getwd(),paths$root,'roads')
paths$grid      = c(getwd(),paths$root,'grid')
paths$tmp       = c(getwd(),paths$root,'tmp')
paths$voronoi   = c(getwd(),paths$root,'voronoi')
paths$int       = c(getwd(),paths$root,'integration')
paths$final     = c(getwd(),paths$root,'final')
paths$os.src    = c(getwd(),paths$root,'src','OS')
paths$osm.src   = c(getwd(),paths$root,'src','OSM')
paths$nspl.src  = c(getwd(),paths$root,'src','NSPL')
paths$osni.src  = c(getwd(),paths$root,'src','OSNI')
paths$grid.src  = c(getwd(),paths$root,'src','OSGB-Grids')

########## Regions Configuration
# The source shapefiles taken from the Ordnance Survey:
r.shp.countries = get.path(paths$os,"Countries-UK.shp")
r.shp.regions   = get.path(paths$os,"Regions-England.shp")

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

########## Grid Configuration
# We need to work out xmin and ymin such that we get a fairly consistent
# output no matter what the user specifies -- in other words, we don't 
# want grids starting at an Easting of 519 or 728 so it makes sense to round
# the bounding box for the region to the nearest... 'x' km?
g.resolution   <- 250                        # Grid resolution (in metres)
g.anchor       <- 5000                       # Anchor grid min/max x and y at nearest... (in metres)

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
# These are amenity IS NOT NULL and 'x' NOT IN... (i.e. all amenities except those below are *included*)
osm.classes$amenity = c('hospice', 'nursing_home', 'retirement_home', 'student_accomodation')

# I do want to distinguish between completely unbuildable and
# 'low density' so this is used in Step 3 of the osm.R file but
# the names need to match *exactly* to the classes above.
osm.classes.developable = c('farmland','farmyard','brownfield','vineyard','marina')

# This *could* be useful in theory but doesn't seem to add much 
# value in practice. Plus you might pick up names of towns and 
# such which wouldn't actually help that much.
#osm.classes$other_tags = c('%Forest%', '%Common%', '%Heath%') # Based on the Other field: "designation"=>"Swinley Forest"

# Merge all classes to deal with inconsistency in tagging
# by OSM contributors -- some have used the 'other' tag 
# instead of the 'natural' or 'landuse' ones.
osm.classes$natural = unique(c(osm.classes$natural, osm.classes$landuse, osm.classes$leisure))
osm.classes$landuse = osm.classes$natural
osm.classes$leisure = osm.classes$natural

########## Roads Configuration
roads.motorway.buffer   <- 1000              # Buffer to draw around roads to filter (in metres)
roads.main.buffer       <-  500
roads.local.buffer      <-  150 
roads.simplify          <-  100              # Simplify the roads before drawing the buffer (for performance)

########## Sanity check -- we only need to run this on startup...
if (! file.exists( r.shp.countries )) {
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat("Have you run the ni-preprocessing.R script yet?\n")
  cat("This is critical to the remaining processes!\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
  cat(paste(replicate(45, "="), collapse = ""), "\n")
}