# Set up the data directories for the 
# user and attempt to download the open
# data that we want where it's easy to 
# access.
cat(paste(replicate(45, "="), collapse = ""), "\n")
cat(paste(replicate(45, "="), collapse = ""), "\n")
cat("Do *not* run this script on a mobile or low-bandwidth connection!","\n")
cat("You are about to download about 2GB of data!\n")
cat(paste(replicate(45, "="), collapse = ""), "\n")
cat(paste(replicate(45, "="), collapse = ""), "\n")

source('funcs.R')
source('config.R')

for (p in ls(paths)) {
  dir.nm = paste(paths[[p]], collapse="/")
  if (p != 'root'){
    cat("Checking for:",dir.nm,"\n") 
    if (! dir.exists( dir.nm )) {
      cat("     > Creating dir","\n")
      dir.create(dir.nm, showWarnings=TRUE, recursive=TRUE)
    } 
  }
}

# Would be nice to add code to download all of the requisite data as well... one day
# download.file(url, destfile, method, quiet = FALSE, mode = "w"

# For Roads processing
download.file('https://github.com/charlesroper/OSGB_Grids/archive/master.zip', get.path(paths$grid.src,'OSGB-Grid.zip'))
unzip(get.path(paths$grid.src,'OSGB-Grid.zip'), exdir=get.path(paths$grid.src))

# For OSM processing
download.file('http://download.geofabrik.de/europe/great-britain/england-latest.osm.pbf', get.path(paths$osm.src,'england-latest.osm.pbf'))
download.file('http://download.geofabrik.de/europe/great-britain/scotland-latest.osm.pbf', get.path(paths$osm.src,'scotland-latest.osm.pbf'))
download.file('http://download.geofabrik.de/europe/great-britain/wales-latest.osm.pbf', get.path(paths$osm.src,'wales-latest2.osm.pbf'))
download.file('http://download.geofabrik.de/europe/ireland-and-northern-ireland-latest.osm.pbf', get.path(paths$osm.src,'northern-ireland-latest.osm.pbf')) # Note change of name!

# For Regional processing 
download.file('https://opendata.arcgis.com/datasets/f99b145881724e15a04a8a113544dfc5_2.zip?outSR=%7B%22wkid%22%3A27700%2C%22latestWkid%22%3A27700%7D', get.path(paths$os.src,'Regions_December_2016_Generalised_Clipped_Boundaries_in_England.zip'))
unzip(get.path(paths$os.src,'Regions_December_2016_Generalised_Clipped_Boundaries_in_England.zip'), exdir=get.path(paths$os.src))

download.file('https://opendata.arcgis.com/datasets/37bcb9c9e788497ea4f80543fd14c0a7_2.zip?outSR=%7B%22wkid%22%3A27700%2C%22latestWkid%22%3A27700%7D', get.path(paths$os.src,'Countries_December_2016_Generalised_Clipped_Boundaries_in_Great_Britain.zip'))
unzip(get.path(paths$os.src,'Countries_December_2016_Generalised_Clipped_Boundaries_in_Great_Britain.zip'), exdir=get.path(paths$os.src))

# Note -- this is a _big_ file!
download.file('http://geoportal.statistics.gov.uk/datasets/055c2d8135ca4297a85d624bb68aefdb_0.csv', get.path(paths$ons.src,'NSPL_MAY_2017_UK.csv'))

download.file('http://osni-spatial-ni.opendata.arcgis.com/datasets/d9dfdaf77847401e81efc9471dcd09e1_0.zip', get.path(paths$osni.src,'OSNI_Open_Data_Largescale_Boundaries__NI_Outline.zip'))
unzip(get.path(paths$osni.src,'OSNI_Open_Data_Largescale_Boundaries__NI_Outline.zip'), exdir=get.path(paths$osni.src))

download.file('http://osni-spatial-ni.opendata.arcgis.com/datasets/f9b780573ecb446a8e7acf2235ed886e_2.zip', get.path(paths$osni.src,'OSNI_Open_Data__50k_Transport_Line.zip'))
unzip(get.path(paths$osni.src,'OSNI_Open_Data__50k_Transport_Line.zip'), exdir=get.path(paths$osni.src))

cat("Done with directly accessible files.\n")
cat("You must download OS OpenRoads using an email address\n")
cat("And then run 01_processing.R\n")