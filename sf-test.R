
rm(list = ls()) # Clear the workspace

source('config.R')
source('funcs.R')

library(sf)

x = st_sfc(st_polygon(list(rbind(c(0,0),c(0.5,0),c(0.5,0.5),c(0.5,0),c(1,0),c(1,1),c(0,1),c(0,0)))))
st_is_valid(x)
y = st_make_valid(x)
st_is_valid(y)

r      = 'England London'
params = set.params(r)

uk.fn  = paste(c(paths$os,'Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp'),collapse="/")
uk.shp = st_read(uk.fn, quiet=TRUE)

rb.shp <- buffer.region(params)

sp.shp <- st_split(uk.shp, rb.shp)