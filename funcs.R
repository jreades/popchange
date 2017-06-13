.simpleCap <- function(x) {
  s <- strsplit(tolower(x), "[_ ]")[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2),
        sep = "", collapse = "_")
}

delete.shp <- function(s) {
  for (ext in c('shp','sbx','dbf','prj','shx')) {
    fn = sub('shp$',ext,s)
    if (file.exists(fn)) {
      file.remove(fn)
    }
  }
}

make.box <- function(s) {
  r.ext = st_bbox(s)
  x.min = floor(r.ext['xmin']/g.anchor)*g.anchor
  y.min = floor(r.ext['ymin']/g.anchor)*g.anchor
  x.max = ceiling(r.ext['xmax']/g.anchor)*g.anchor
  y.max = ceiling(r.ext['ymax']/g.anchor)*g.anchor
  
  # Create a box for this
  box <- st_polygon(list(rbind(c(x.min,y.min),c(x.max,y.min),c(x.max,y.max),c(x.min,y.max),c(x.min,y.min))))
  box <- st_sfc(box) %>% st_set_crs(NA) %>% st_set_crs(27700)
  box
}

buffer.region <- function(r) {
  
  params = set.params(r)
  
  if (r %in% c('Northern Ireland','Wales','Scotland')) { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(paste(c(os.path, "CTRY_DEC_2011_UK_BGC.shp"), collapse="/"), stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$CTRY11NM==params$country,]
    
  } else { # Filtering for regions
    r.filter.name <- sub("^[^ ]+ ","",r, perl=TRUE)
    cat("  Processing internal GoR region:", params$region,"\n") 
    
    shp <- st_read(paste(c(os.path, "Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"), collapse="/"), stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- shp[shp$FILE_NAME==r.filter,]
    # Use this for filtering on GOR regions:
    r.shp <- shp[shp$rgn16nm==params$region,]
  }
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.")
  r.buff = st_buffer(st_simplify(r.shp, r.simplify), r.buffer)
  r.buff
}

get.region <- function(r) {
  
  params = set.params(r)
  
  if (r %in% c('Northern Ireland','Wales','Scotland')) { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(paste(c(os.path, "CTRY_DEC_2011_UK_BGC.shp"), collapse="/"), stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$CTRY11NM==params$country,]
    
  } else { # Filtering for regions
    r.filter.name <- sub("^[^ ]+ ","",r, perl=TRUE)
    cat("  Processing internal GoR region:", params$region,"\n") 
    
    shp <- st_read(paste(c(os.path, "Regions_December_2016_Generalised_Clipped_Boundaries_in_England.shp"), collapse="/"), stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- shp[shp$FILE_NAME==r.filter,]
    # Use this for filtering on GOR regions:
    r.shp <- shp[shp$rgn16nm==params$region,]
  }
  
  r.shp
}
# 
# fixholes = function(sp.obj) {
#   require(rgeos)
#   require(stringr)
#   require(maptools)
#   if(!inherits(sp.obj, "SpatialPolygons")) stop("Input object must be of class SpatialPolygons")
#   pls = slot(sp.obj, "polygons")
#   pls1 = lapply(pls, maptools::checkPolygonsHoles)
#   slot(sp.obj, "polygons") = pls1
#   return(sp.obj)
# }
# 
# spdf2owin = function(spdf) {
#   cp <- as(spdf, "SpatialPolygons")
#   cregions <- slot(cp, "polygons")
#   cregions <- lapply(cregions, function(x) { fixholes(SpatialPolygons(list(x))) })
#   cwindows <- lapply(cregions, as.owin)
#   ch <- hyperframe(window=cwindows)
#   ch <- cbind.hyperframe(ch, spdf@data)
#   return(ch)
# }

set.params <- function(r) {
  the.label   <- .simpleCap(r)
  the.country <- strsplit(r, " ")[[1]][1]
  the.region  <- paste(strsplit(r, " ")[[1]][-1], collapse=" ")
  
  if (r=='Northern Ireland') {
    the.country <- 'Northern-Ireland'
    the.region  <- ""
  }
  
  params             = new.env()
  params$label       = the.label
  params$country     = the.country
  params$region      = the.region
  params$osm.country = tolower(the.country)
  
  params
}