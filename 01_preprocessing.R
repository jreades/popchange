rm(list = ls())
# Merge the NI data into the OSGB data set to simplify
# the processing of the UK data stack.

source('funcs.R')
source('config.R')

r = 'Northern Ireland'
params = set.params(r)

# Create raster grid of arbitrary size:
# https://gis.stackexchange.com/questions/154537/generating-grid-shapefile-in-r

raw.source   = get.path(paths$osni.src, "OSNI_Open_Data_Largescale_Boundaries__NI_Outline.shp")
merge.source = get.path(paths$osni, "OSNI_Boundaries-*.shp")
os.source    = get.path(paths$os.src, "Countries_December_2016_Generalised_Clipped_Boundaries_in_Great_Britain.shp")
merge.target = get.path(paths$os, "Countries_UK.shp")
sql.update   = "UPDATE Countries_UK SET ctry16nm='Northern Ireland', objectid=4, ctry16cd='N92000005' WHERE ctry16nm IS NULL"

########### OSM Data
# Copy the OSM file so that we can work with 
# it more easily using the same approach as for
# the rest of Great Britain. If setup.R has been
# run properly then this should be unnecssary, 
# but this is a handy check.
dfile = get.path(paths$osm.src, paste(params$osm,"latest.osm.pbf",sep="-"))
if (! file.exists(dfile)) {
  file.copy(
    get.path(paths$osm.src, "ireland-and-northern-ireland-latest.osm.pbf"),
    dfile
  ) 
} else {
  cat("OSM file already renamed and in place.","\n")
}
rm(dfile)

########### OS Data
# Copy the regions file to the right place
regions.src  = get.path(paths$os.src,"Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp")
regions.dest = get.path(paths$os,"Regions_England.shp")
for (ext in c('shp','dbf','shx','sbn','sbx','prj')) {
  file.copy(gsub('shp$',ext,regions.src), gsub('shp$',ext,regions.dest)) 
}

# Copy the source GB file to UK since we're 
# picking up the rest of Northern Ireland
for (ext in c('shp','dbf','shx','sbn','sbx','prj')) {
  file.copy(gsub('shp$',ext,os.source), gsub('shp$',ext,merge.target)) 
}

# Reproject the NI data (though it was EPSG:29901 but apparently not)
cmd1 = c('-f "ESRI Shapefile"', paste('-t_srs EPSG',crs.gb,sep=":"), paste('-s_srs EPSG',crs.osm,sep=":"), get.file(t=merge.source,crs.gb), raw.source, '-overwrite', '--config ogr_interleaved_reading yes',';')
cat(ogr.lib, cmd1,"\n")
system2(ogr.lib, cmd1, wait=TRUE)

# Merge the NI and GB data to give UK
cmd2 = c(merge.target, get.file(t=merge.source,crs.gb), '-append', '-update',';')
cat(ogr.lib, cmd2,"\n")
system2(ogr.lib, cmd2, wait=TRUE)

# And now we need to set at least the Country Name
# in the merged shapefile so that we can select
# Northern Ireland
cmd3 = c(merge.target, '-dialect SQLite', paste('-sql "', sql.update, '"', sep=" "))
cat(ogr.info, cmd3,"\n")
system2(ogr.info, cmd3, wait=TRUE)

# And make a copy of the NI data in the *correct* projection
cmd4 = c('-f "ESRI Shapefile"', paste('-t_srs EPSG',crs.ni,sep=":"), paste('-s_srs EPSG',crs.osm,sep=":"), get.file(t=merge.source,crs.ni), raw.source, '-overwrite', '--config ogr_interleaved_reading yes',';')
cat(ogr.lib, cmd4, "\n")
system2(ogr.lib, cmd4, wait=TRUE)

cat("Done, you're now ready to run the rest of the scripts.\n\n")
