library(Hmisc)
library(zoo)
library(reshape2)
library(data.table)
library(plyr)     # for rbind.fill
library(dplyr)
library(dtplyr)
library(sf)

#library(spatstat) # Required for owin
#library(sp)       # Required for KDE process
#require(rgdal)    # Required for readOGR to get around issue with sf and running KDE

.simpleCap <- function(x) {
  s <- strsplit(tolower(x), "[_ ]")[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2),
        sep = "", collapse = "_")
}

#' Utility function to delete a shapefile since 
#' they are actually composed of up to six separate
#' files (QIX are used as spatial indexes by OGR).
#' @param s Full path to shapefile (.shp) to be deleted
delete.shp <- function(s) {
  for (ext in c('shp','sbx','dbf','prj','shx','qix')) {
    fn = sub('shp$',ext,s)
    if (file.exists(fn)) {
      file.remove(fn)
    }
  }
}

#' Create a bounding box from a shapefile that rounds 
#' down on xmin/ymin and up on xmax/ymax according to a 
#' specified amount.
#' @param s Source shapefile from which to create a bounding box
#' @param proj Optional: projection (defaults to 27700 BNG)
#' @param a Optional: anchor to specifying rounding amount (defaults to g.anchor from config file)
#' @return a bounding box sf object
make.box <- function(s, proj=27700, a=g.anchor) {
  r.ext = st_bbox(s)
  x.min = floor(r.ext['xmin']/a)*a
  y.min = floor(r.ext['ymin']/a)*a
  x.max = ceiling(r.ext['xmax']/a)*a
  y.max = ceiling(r.ext['ymax']/a)*a
  
  # Create a box for this
  create.box(x.min, x.max, y.min, y.max, proj)
}

#' Create a box directly from a set of four coordinates
#' passed to the function.
#' @param x.min The minimum x-coordinate
#' @param x.max The maximum x-coordinate
#' @param y.min The minimum y-coordinate
#' @param y.max The maximum y-coordinate
#' @param proj Optional: the projection (defaults to EPSG:27700)
create.box <- function(x.min, x.max, y.min, y.max, proj=27700) {
  box <- st_polygon(list(rbind(c(x.min,y.min),c(x.max,y.min),c(x.max,y.max),c(x.min,y.max),c(x.min,y.min))))
  box <- st_sfc(box) %>% st_set_crs(NA) %>% st_set_crs(proj)
  box
}

#' Retrieve the buffered boundary for a region from the appropriate
#' shapefile -- for NI, Scotland and Wales this will be the
#' UK file, for England this will be Regions file.
#' @param r Region name (e.g. 'Northern Ireland', 'England South West', 'Scotland')
#' @param simplify Threshold for simplifying prior to buffering (defaults to r.simplify from config file)
#' @param buffer Amount by which to buffer area polygon (defaults to r.buffer)
#' @return sfc object containing simplified, buffered regional outline
buffer.region <- function(p, simplify=r.simplify, buffer=r.buffer) {
  
  params = p
  
  if (params$country.nm %in% c('Northern Ireland','Wales','Scotland')) { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(r.shp.countries, stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$ctry16nm==params$country.nm,]
    
  } else { # Filtering for regions
    cat("  Processing internal GoR region:", params$region.nm,"\n") 
    
    shp <- st_read(r.shp.regions, stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- shp[shp$FILE_NAME==r.filter,]
    # Use this for filtering on GOR regions:
    r.shp <- shp[shp$rgn16nm==params$region.nm,]
  }
  
  # Region-Buffered shape
  cat("  Simplifying and buffering region to control for edge effects.\n")
  r.buff = st_buffer(st_simplify(r.shp, simplify), buffer)
  r.buff
}

#' Retrieve the boundary for a region from the appropriate
#' shapefile -- for NI, Scotland and Wales this will be the
#' UK file, for England this will be Regions file.
#' @param r Region name (e.g. 'Northern Ireland', 'England South West', 'Scotland')
#' @return sfc object containg outline of region
get.region <- function(p) {
  
  params = p
  
  if (params$country.nm %in% c('Northern Ireland','Wales','Scotland')) { # No filtering for regions
    cat("  No filter. Processing entire country.\n")
    
    shp <- st_read(r.shp.countries, stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection (issues with reading in even properly projected files)
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp)) # Check reprojection
    
    # Extract country from shapefile
    r.shp <- shp[shp$ctry16nm==params$country.nm,]
    
  } else { # Filtering for regions
    cat("  Processing internal GoR region:", params$region.nm,"\n") 
    
    shp <- st_read(r.shp.regions, stringsAsFactors=TRUE, quiet=TRUE)
    
    # Set projection
    shp <- shp %>% st_set_crs(NA) %>% st_set_crs(27700)
    #print(st_crs(shp))
    
    # Would need to implemented this way for filtering on districts: 
    #r.shp <- shp[shp$FILE_NAME==r.filter,]
    # Use this for filtering on GOR regions:
    r.shp <- shp[shp$rgn16nm==params$region.nm,]
  }
  
  r.shp
}

#' Simple utility function to set up the parameter environment
#' used across the whole set of scripts -- this helps to ensure
#' that files are read/written to the same place, and that we can 
#' pick the data we need out of the source shapefiles.
#' @param r Region name (e.g. 'Northern Ireland', 'England South West', 'Scotland')
set.params <- function(r) {
  the.country <- strsplit(r, " ")[[1]][1]
  the.region  <- paste(strsplit(r, " ")[[1]][-1], collapse=" ")
  
  if (r=='Northern Ireland') {
    the.country <- 'Northern Ireland'
    the.region  <- ""
  }
  
  params             = new.env()
  params$country.nm  = the.country
  params$region.nm   = the.region
  params$display.nm  = (if(the.country=='England') { the.region } else { the.country })
  params$file.nm     = .simpleCap( (if(the.country=='England') { the.region } else { the.country }) )
  params$country     = .simpleCap(the.country)
  params$region      = .simpleCap(the.region)
  params$osm         = tolower(.simpleCap(the.country))
  
  params
}

#' Simple utility function to return a full file path
#' from a list of path elements and a filename.
#' @param p The path (as list)
#' @param fn The file name (as a string, preferrably)
#' @param c Optional: the concatentation var to use (defaults to auto-detecting platform)
get.path <- function(p, fn=NULL, c=NULL) {
  if (Sys.info()[['sysname']] == 'Windows') {
    c="\\"
  } else {
    c="/"
  }
  if (is.null(fn)) {
    path = paste( p, collapse=c)
  } else {
    path = paste( c(p,fn), collapse=c) 
  }
  path
}

#' Generate a file name using a mix of a template (t) and 
#' any other parameters passed to the function.
#'
#' In order to ensure that file outputs and inputs are named
#' in a predictable way, and to improve legibility of
#' the code, this function takes a template string and 
#' interpolates a number of environment and local variables
#' into the template. If no template string is passed then
#' the parameters are simply concatenated and returned.
#' 
#' Templates are of the form "{env1}-{var2}-Grid-*.shp". In this
#' case env1 is a key from the params environment (by default the
#' one used in this set of scripts, but can be overridden by passing
#' in a parameter p) and var2 is simply a variable accessible by the
#' function. * is where any other strings passed to the function 
#' would be interpolated using the concatenation parameter c (which
#' defaults to '_' as being the most system-friendly option).
#' 
#' This need sanitising -- it might be possible to pass
#' in arbitrary code and this currently uses eval() as I can't 
#' figure out how the quote() approach works.
#' @param t The template string to be used (if any)
#' @param p Optional: the environment from which to extract key/value pairs
#' @param c Optional: the concatentation character to use
#' @param ... Optional: any other values to be interpolated where there is a '*' in the string
#' @return A string suitable for using as a file name
get.file <- function(..., t=NULL, p=params, c="_") {
  
  if (is.null(t)) { # If no template then just collapse using least problematic char
    rt = paste( list(...), collapse=c)
  
  } else { # Template that needs interpolation
    
    # Find and extract all matche
    m <- gregexpr("(?<=\\{)[^\\}]+(?=\\})",t,perl=TRUE)
    v <- regmatches(t,m)
    
    # Copy to the return val and use that for subs
    rt = t
    
    # For each match
    for (hit in unlist(v)) {
      
      # Is it in the params environment?
      if (sum(grepl(hit, ls(p))) > 0) {
        rt = gsub(paste("\\{",hit,"\\}",sep=""), eval(parse(text=paste("p$",hit,sep=""))), rt, perl=TRUE)
      
      # Raw variable name?
      } else {
        rt = gsub(paste("\\{",hit,"\\}",sep=""), eval(parse(text=hit)), rt)
      }
    }
    
    # Interpolate anything else if there's a '*'
    rest = paste( list(...), collapse=c)
    rt = gsub("\\*",rest,rt)
  }
  rt
}