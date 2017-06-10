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

set.params <- function(r) {
  the.label   <- .simpleCap(r)
  the.country <- strsplit(r, " ")[[1]][1]
  the.region  <- paste(strsplit(r, " ")[[1]][-1], collapse=" ")
  
  if (r=='Northern Ireland') {
    the.country <- 'Northern-Ireland'
    the.region  <- ""
  }
  
  params         = new.env()
  params$label   = the.label
  params$country = the.country
  params$region  = the.region
  params
}