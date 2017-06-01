rm(list = ls())
# Merge the NI data into the OSGB data set to simplify
# the processing of the UK data stack.

source('config.R')

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

raw.source   = paste(c(os.path, "OSNI_Open_Data_Largescale_Boundaries__NI_Outline.shp"), collapse="/")
merge.source = paste(c(os.path, "OSNI_Open_Data_Largescale_Boundaries__NI_Outline-reprojected.shp"), collapse="/")
os.source    = paste(c(os.path, "CTRY_DEC_2011_GB_BGC.shp"), collapse="/")
merge.target = paste(c(os.path, "CTRY_DEC_2011_UK_BGC.shp"), collapse="/")
sql.update   = "UPDATE CTRY_DEC_2011_UK_BGC SET CTRY11NM='Northern-Ireland' WHERE CTRY11NM IS NULL"

# Copy the source GB file to UK since we're 
# picking up the rest of Northern Ireland
for (ext in c('shp','dbf','shx','sbn','sbx','prj')) {
  file.copy(gsub('shp$',ext,os.source), gsub('shp$',ext,merge.target)) 
}

# Copy the OSM file so that we can work with 
# it more easily using the same approach as for
# the rest of Great Britain
file.copy(
  paste(c(osm.path, "ireland-and-northern-ireland-latest.osm.pbf"), collapse="/"), 
  paste(c(osm.path, "northern-ireland-latest.osm.pbf"), collapse="/")
)

# Reproject the NI data
cmd1 = c('-f "ESRI Shapefile"', '-t_srs EPSG:27700', '-s_srs EPSG:29901', merge.source, raw.source, '-overwrite', '--config ogr_interleaved_reading yes',';')
print(paste(c(ogr.lib, cmd1), collapse=" "))
system2(ogr.lib, cmd1, wait=TRUE)

# Merge the NI and GB data
cmd2 = c(merge.target, merge.source, '-append', '-update',';')
print(paste(c(ogr.lib, cmd2), collapse=" "))
system2(ogr.lib, cmd2, wait=TRUE)

# And now we need to set at least the Country Name
# in the merged shapefile so that we can select
# Northern Ireland
cmd3 = c(merge.target, '-dialect SQLite', paste('-sql "', sql.update, '"', sep=" "))
print(paste(c(ogr.info, cmd3), collapse=" "))
system2(ogr.info, cmd3, wait=TRUE)

cat("Done, you're now ready to run the rest of the scripts.\n\n")