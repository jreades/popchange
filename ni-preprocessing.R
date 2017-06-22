rm(list = ls())
# Merge the NI data into the OSGB data set to simplify
# the processing of the UK data stack.

source('funcs.R')
source('config.R')

params = set.params("Northern Ireland")

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

raw.source   = get.path(paths$osni.src, c('OSNI_Open_Data_Largescale_Boundaries__NI_Outline',"OSNI_Open_Data_Largescale_Boundaries__NI_Outline.shp"))
merge.source = get.path(paths$osni, "OSNI_Boundaries-reprojected.shp")
os.source    = get.path(paths$os.src, c("Countries_December_2016_Generalised_Clipped_Boundaries_in_Great_Britain","Countries_December_2016_Generalised_Clipped_Boundaries_in_Great_Britain.shp"))
merge.target = get.path(paths$os, "Countries_UK.shp")
sql.update   = "UPDATE Countries_UK SET ctry16nm='Northern Ireland', objectid=4, ctry16cd='N92000005' WHERE ctry16nm IS NULL"

########### OSM Data
# Copy the OSM file so that we can work with 
# it more easily using the same approach as for
# the rest of Great Britain
file.copy(
  paste(c(paths$osm.src, "ireland-and-northern-ireland-latest.osm.pbf"), collapse="/"), 
  paste(c(paths$osm.src, paste(params$osm,"latest.osm.pbf",sep="-")), collapse="/")
)

########### OS Data
# Copy the source GB file to UK since we're 
# picking up the rest of Northern Ireland
for (ext in c('shp','dbf','shx','sbn','sbx','prj')) {
  file.copy(gsub('shp$',ext,os.source), gsub('shp$',ext,merge.target)) 
}

# Copy the regions file to the right place
regions.src  = get.path(paths$os.src,c("Regions_December_2016_Generalised_Clipped_Boundaries_in_England","Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"))
regions.dest = get.path(paths$os,"Regions_England.shp")
for (ext in c('shp','dbf','shx','sbn','sbx','prj')) {
  file.copy(gsub('shp$',ext,regions.src), gsub('shp$',ext,regions.dest)) 
}

# Reproject the NI data
cmd1 = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:29901', merge.source, raw.source, '-overwrite', '--config ogr_interleaved_reading yes',';')
cat(ogr.lib, cmd1,"\n")
system2(ogr.lib, cmd1, wait=TRUE)

# Merge the NI and GB data to give UK
cmd2 = c(merge.target, merge.source, '-append', '-update',';')
cat(ogr.lib, cmd2,"\n")
system2(ogr.lib, cmd2, wait=TRUE)

# And now we need to set at least the Country Name
# in the merged shapefile so that we can select
# Northern Ireland
cmd3 = c(merge.target, '-dialect SQLite', paste('-sql "', sql.update, '"', sep=" "))
cat(ogr.info, cmd3,"\n")
system2(ogr.info, cmd3, wait=TRUE)

cat("Done, you're now ready to run the rest of the scripts.\n\n")
