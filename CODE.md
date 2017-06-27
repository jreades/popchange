<!-- test compile using X -->

## SF & Other Libs on a Mac

On my Mac I've intalled GDAL and GEOS using the libraries provided by [KyngChaos](http://www.kyngchaos.com/software/frameworks). These put the necessary external resources (GDAL, GEOS, PROJ) under `/Library/Frameworks/...`

To install a version of `sf` that enables `st_voronoi` functionality, however, you **_must_** link to a version of `GEOS` > 3.5. Installing `rgeos` and `sf` via RStudio repeatedly linked to older compiled versions from CRAN for me (even when I tried to install using `type='source'`) so I eventually tried downloading the tarball from CRAN, `gunzip`-ing it, and installing from the Terminal:
```
R CMD INSTALL rgeos_0.3-23.tar.gz --configure-args='--with-geos-config=/Library/Frameworks/GEOS.framework/unix/bin/geos-config'
R CMD INSTALL sf_0.4-3.tar --configure-args='--with-geos-config=/Library/Frameworks/GEOS.framework/unix/bin/geos-config --with-proj-include=/Library/Frameworks/PROJ.framework/Headers --with-proj-lib=/Library/Frameworks/PROJ.framework/unix/lib'
```

This **_should have worked_** but did not. In retrospect, I think that this might have been because I'd missed an old compiler flag in my `.bash_profile` that was pointing to GDAL 1.11 (which no longer existed). The correct bash parameter would have been:
```
export CFLAGS=Library/Frameworks/GDAL.framework/unix/bin/gdal-config
```

But there is an _additional_ issue lurking in the background, and that the need to link to `liblwgeom` in order to access `st_split` and `st_make_valid`. Conequently, I finally resorted to Homebrew (which I had already installed and which probably didn't help with compiling `sf`) and did thing in the following order:
```
brew doctor # And deal with any major issues (e.g. alert about Anaconda, see below)
brew prune
brew update
brew tap osgeo/osgeo4mac && brew tap --repair
brew install postgis --build-from-source # To get liblwgeom links sorted
brew install homebrew/science/netcdf
brew install jasper
brew install gdal2 --with-armadillo --with-complete --with-libkml --with-unsupported --with-postgresql
brew link --force gdal2
cp /usr/local/opt/gdal2/lib/libgdal.20.dylib /usr/local/opt/gdal2/lib/libgdal.20.dylib.orig
chmod +w /usr/local/opt/gdal2/lib/libgdal.20.dylib
install_name_tool -change @rpath/libjasper.4.dylib /usr/local/opt/jasper/lib/libjasper.4.dylib -change @rpath/libnetcdf.11.dylib /usr/local/opt/netcdf/lib/libnetcdf.11.4.0.dylib /usr/local/opt/gdal2/lib/libgdal.20.dylib
```

### Important Note
Since I had Anaconda Python installed I also ended up mucking about with my `.bash_profile` before doing the Homebrew work, and it ended up looking like this:
```
export PATH="/usr/local/opt/gdal2/bin:$PATH"
export CFLAGS="/usr/local/opt/gdal2/bin/gdal-config"
export CPPFLAGS="/usr/local/opt/gdal2/bin/gdal-config"
export LD_LIBRARY_PATH="/usr/local/opt/gdal2/lib:$LD_LIBRARY_PATH"

# This doesn't coexist happily with gdal2 installed via homebrew
#export PATH="/Applications/anaconda/bin:$PATH"
```

Note the commenting out of the anaconda path _while installing and configuring gdal via brew_.

Finally, I had to reinstall `rgeos` and `rgdal` (and added `sp` for good measure) to get everything working. 
```
install.packages('rgdal')
install.packages('rgeos')
install.packages('sp')
```

When these libraries are imported you can install `sf` via:
```
library(devtools)
devtools::install_github('edzer/sfr')
```
You should see a version of GEOS >= 3.5 and GDAL > 2.0 being used when `sf` is imported.

**_If you are starting this with a clean system I'd appreciate an update on which approach worked for you!_**

# Generating Grids

The R scripts contained in this project repo allow you to take any Census attribute for any Census year (1971-2011) and convert it to a regular grid for some or all of Great Britain (Scotland, England & Wales).

In order to run the scripts, you will need to do a number of things:
- Ensure that you have GDAL, it's associated tools, and all of the requisite R libraries installed.
- Adjust the [config.R](./config.R) file to suit your needs.
- Download the open data upon which the gridding (a.k.a. rasterisation) process depends.
- Download the Census data that you want to rasterise.

Let's tackle each of these turn...

# GDAL and R

Although there is no reason why the code in this project would _not_ work on Windows, I do not have (and do not intend to purchase) a Windows system for the purposes of testing this. The principal issue that I would anticipate is that the paths will become problematic so the code to write/read data will become substantially more complex. A function might take care of this without too much trouble, but it's not a high priority for me. It's open source: if you want it, then please feel free to fork and contribute!

### GDAL / OGR

GDAL should be fairly easy to install on a \*nix system of any flavour as the libraries should be available via 'app stores' and also as compilable source. On a Mac, I typically use the excellent [KyngChaos](http://www.kyngchaos.com/software/frameworks) installers as they also support QGIS out-of-the-box.

We need GDAL because we make extensive use of the [ogr2ogr](http://www.gdal.org/ogr2ogr.html) utility. Although many of the operations performed could _theoretically_ be done within a R-only solution, `ogr2ogr` is much, much faster and less memory-intensive. It also gives us a way to translate between many different formats and to dynamically clip the input region (which is essential for England since there is just so much data).

### R libraries

This code makes use of the following R libs:

- DBI
- data.table
- ggplot2
- raster
- rgdal
- sf
- zoo

The `sf` library is the long-term replacement for `sp` and does away with the need to do things like fortify the data frame. Performance seems pretty good too and it uses a PostgreSQL/PostGIS-like approach that includes functions like `st_buffer` and `st_simplify`!

The `raster` library is used to create the underlying grid.

# Open Data Resources

The idea of this fork to try to make a fully replicable process that draws solely on open data and a FOSS stack, and that can be run solely as code without recourse to Arc or QGIS. _(Yes, I know QGIS is scriptable.)_

## OpenStreetMap (OSM)

We work from the premise that certain types of land use were highly unlikely to ever have _been_ built on in any meaningful way over the time period covered by digitised Censuses (Censi?) going back to the 1970s. We can use those areas to influence our calculation of population dispersion when we take our EDs and OAs and need to apportion them across more than one grid cell. It won't be perfect, but it should be more robust than existing approaches which are based solely on smoothing and assignment by centroid.

For simplicty's sake, we use the PBF resources provided by GeoFabrik:

* England OSM (> 700MB): [england-latest.osm.pbf](http://download.geofabrik.de/europe/great-britain/england-latest.osm.pbf)
* Scotland OSM (> 100MB): [scotland-latest.osm.pbf](http://download.geofabrik.de/europe/great-britain/scotland-latest.osm.pbf)
* Wales OSM (> 50MB): [wales-latest.osm.pbf](http://download.geofabrik.de/europe/great-britain/wales-latest.osm.pbf)
* Northern Ireland / Ireland OSM (> 125MB): [ireland-and-northern-ireland-latest.pbf](http://download.geofabrik.de/europe/ireland-and-northern-ireland-latest.osm.pbf)

These files will need to be placed in the correct directory (and they should all have names as per the original downloaded file) so that the scripts can find them.

### Why Not Use OS OpenData?

Increasingly, the OS provides high-resolution open data for non-commercial (and commercial) applications, so why not use, say, the buildings layer from the OS Local data? There are two reasons for this:

1. Because the building-level data is broken up by grid tile and zipped together with a host of other features. Consequently, downloading this data for all of Great Britain would entail downloading many GB of data, most of which we don't actually need, and the portions of which we do need balloon the in-memory process into many GB as wel!

2. Becase the buildings are actually changing and we have no history in the OS's data set of when a particular building was constructed. Consequently, it makes more sense to _exclude_ land uses that are incompatible with development (forst, reservoirs, etc.) from the weighting of the grid instead of _including_ only those areas that we think were built upon.

These two issues push us towards using the OSM data instead: it's more manageable to download and process, and it's more compatible with land use analysis. An _additional_ benefit of this approach is the gain we make in terms of potential comparability/reuse across countries. Right now the process as developed is only for Great Britain, but in principle it should be possible to fork/update the code to run anywhere else that has OSM coverage and where we can work out a fairly reliable ontology for land use.

### Filtering Out Areas

What we're aiming for here is _excluding_ those parts of Great Britain that are unlikely to have been developed, and to then have reverted to an undeveloped land within the timeframe of a downloadable Census (i.e. 1971 onwards). So we wouldn't expect marsh to emerge on land that was previously used for housing, for instance.

The only widely available source of high-res *open* data on such areas is OSM. The Ordnance Survey has some very nice  open data for Great Britain but that doesn't generalise well (especially for the locations of buildings). As well, their boundary line polygon data is not clipped to the high-water mark, so that's another place we'll get 'development' creeping into places it won't have happened. Meanwhile, the polyline high-water data can't be used to clip the boundary polygons because they aren't 'closed'.

More details can be found in the `osm.R` file.

## Ordnance Survey (OS)

We do make use of _some_ OS data because it remains the most accurate and, increasinly, is available on an open basis. The [GeoPortal](https://geoportal.statistics.gov.uk/datasets/) (when it's working) is the best way to access this data:

* Admin boundaries: [Regions 2016 Generalised Clipped Boundaries in England](http://geoportal.statistics.gov.uk/datasets/regions-december-2016-generalised-clipped-boundaries-in-england)
* Country boundaries: [Countries 2016 Generalised Clipped Boundaries in Great Britain](http://geoportal.statistics.gov.uk/datasets/countries-december-2016-generalised-clipped-boundaries-in-great-britain)

You could also get most of this via [OSM's land polygons](http://openstreetmapdata.com/data/land-polygons), but this data set is clipped further inland for tidal rivers (e.g. the Thames) so it produces better result.

We use these to achieve two things:
1. To give us the country boundaries that are needed for processing Wales and Scotland, while also clipping all three nations to the high-water line.
2. To give us the regions that makes up England so that we can break up the processing into smaller chunks.

In short, \#2 gives us access to parallelisation options as long as the grid aligns across regional boundaries (more on this in the `grid.R` file).

## Ordnance Survey of Norther Ireland (OSNI)

For reasons best known to itself, OSNI has made it far more difficult to find and access open data -- I couldn't even locate information about what projection was being used! At any rate, the large scale boundary data set _is_ open and can be downloaded for free, so this is what I've used:

* NI boundaries: [OSNI Open Data Largescale Boundaries - NI Outline](http://osni-spatial-ni.opendata.arcgis.com/datasets/d9dfdaf77847401e81efc9471dcd09e1_0) (subject to change, I'd expect)

The projection is EPSG:29901 (OSNI 1952 / Irish National Grid).

**_Note: in order to make this work reasonably efficiently, you will need to run a pre-processing step on the NI data in order to merge it into the OS GB data set. I have written code to complete this step for you._**

## National Statistics Postcode Lookup

Work by the PopChange PI, [Chris Lloyd](https://www.liverpool.ac.uk/environmental-sciences/staff/christopher-lloyd/), indicates that postcode centroids are a useful proxy for population density ([Google Scholar](https://scholar.google.co.uk/citations?user=E-1TaYoAAAAJ&hl=en&oi=sra)).

There are a number of postcode resources available for the UK, including the seemingly promising CodePoint-Open via the OS Open Data. Unfortunately, that data set has no 'history' so we can't track the introduction and termination of postcodes.

There are two sources that _do_ have this history:
1. The NSPL
2. The ONSPD

A discussion of the tradeoffs between these two data sets can be found here in the National Archives [web archive](http://webarchive.nationalarchives.gov.uk/20160105160709/http://www.ons.gov.uk/ons/guide-method/geography/products/postcode-directories/-nspp-/index.html).

For consistency with earlier work we've opted to use the CSV file for the latest NSPL from the [GeoPortal](https://geoportal.statistics.gov.uk):

* [National Statistics Postcode Lookup (Latest) Centroids](https://opendata.arcgis.com/datasets/055c2d8135ca4297a85d624bb68aefdb_0.csv)

More details can be found in the `nspl.R` file.

## Roads

The location of roads is helpful in terms of constraining where population can be assigned when working with smaller grid sizes. For, say, a 100m grid you would have many empty cells, particularly in rural areas, and using the centroid or smearing the population across the entire postcode would return results that looked fairly improbable to users. One way around this is to think about the cues provided by roads and the ways that they are markers of settlement patterns. Using this approach would allow us to deal with some persistent issues relating to the way that development is allowed/has happened inside national parks and AONB boundaries (for instance) such that you can't simply use the boundaries of a national park as the basis for population suppression in the way that you *can* use smaller woodlands or forests or lakes. In this context, we might want to insist that only grid cells within a set distance of a road (of any grade) can be assigned population and use that as an additional constraint with the land use filter.

### OSM Roads

Currently, we only process polygon features from the OSM data files, so this excludes rivers and roads from our grid weighting process. Somehow OSM 'knows' how to render river and road widths from the centreline, but I can't quite figure it out (yet) from the Geofabrik pre-compiled downloads. I think that, for pragmatic reasons, they may not even contain the road data at the level I want (certainly not in NI) so we need to think what could be done to select and download line features (roads and large rivers) to help suppress 'non-buildable' areas and also to constrain areas where development _could_ occur.

### Open Roads

There _is_ road network data available from other sources: both the Ordnance Survey and OSNI produce open data products for roads. They tend not to go down to the driveway level, which is a shame as this would be particularly helpful in rural areas for locating households, but they're pretty good overall save for the fact that they don't use the same file layout or classification.

#### England & Wales

I have made use of the "OS Open Roads" data product (ca. 500MB) available from the OS Open site: 

* [OpenData Products](https://www.ordnancesurvey.co.uk/opendatadownload/products.html).

Having reviewed the available data and the [Open Roads User Guide](https://www.ordnancesurvey.co.uk/docs/user-guides/os-open-roads-user-guide.pdf), I've opted to use the `function` attribute since this is more useful than the road classification. We make use of the following functions:

* Motorway
* A Road
* B Road
* Minor Road
* Local Road
* Local Access Road

We do not keep:
* Restricted Local Access Road (often industrial estates, farms, parks, cemeteries)
* Secondary Access Road (typically back alleys and field access it seems)

#### Northern Ireland

I have made us of the "OSNI Open Data - 50k Transport Line" data set (ca. 3MB) available from:

* [OSNI Open Data - 50k Transport Line](http://osni-spatial-ni.opendata.arcgis.com/datasets/f9b780573ecb446a8e7acf2235ed886e_2)

OSNI doesn't not provide the same functional definition of the roads in Norther Ireland that the OS does for Great Britain so we need to deal with the `TEMA` field:
* A_CLASS    (mapped to `A Class`)
* B_CLASS    (mapped to `B Class`)
* MOTORWAY   (mapped to `Motorway`)
* DUAL_CARR  (mapped to `Motorway`)
* <4M_TARRED (mapped to `Local Road`)
* CL_MINOR   (mapped to `Minor Road`)

We can drop:
* CL_M_OVER  (could be mapped to `Minor Road` but dropped to prevent overcounting of road density)
* <4M_T_OVER (could be mapped to `Local Road` but dropped to prevent overcounting of road density)
* CL_RAIL    (Rail)
* RL_TUNNEL  (Rail Tunnel)
* UNSHOWN_RL (Unshown Rail [Rail Under Overpass, so not actually a tunnel])

---
_**I have not done any work from here on to update the documentation**_

# Census Data Resources

If you wish to calculate grids for another variable, download data:

- Casweb (1971 - 2001)
- - For 2001, you need to do England, Scotland and Wales separately and combine them into one file (usually the variable structure matches for England and Wales, and is similar for Scotland).
- - For 1991, some tables are structured differently and so you need to download separately and combine them as above.
- - For 1971, need to run code to allocate 71 EDs to 81 EDs As per script.

- For 2011
- - England download from Nomis (https://www.nomisweb.co.uk/census/2011/bulk/r2_2) for England and Wales
- - Scotland download from Scotland Census (http://www.scotlandscensus.gov.uk/ods-web/data-warehouse.html#bulkdatatab)
- - Some Scotland variables are ordered very differently (e.g. Country of Birth & Ethnicity). Combine these carefully!
- - Also replace '- 'in Scotland 11 with '0'. This is easiest done in TextWrangler than LibreOffice Calc.)

The OA proportions layer is provided.

If you are looking to provide the grids you generate back to the resource, please add the info into data-summary.xlsx.

Work out field names (max 8 characters)
- Copy field names into input data file.

## Preparing Census Data

Prepare the Census data you wish to use. An example of this file is OA_attributes.csv / OA_1991_attributes.csv. This is a CSV file containing a list of all the OAs or EDs (depending on the census year) and the one or more attributes you wish to create a grid for. One grid will be created for each attribute you enter. For example:

|  GeographyCode | AllPresRes  |  TotalPop | EtWh  |  EtBlCab |
| --- | --- | --- | --- | --- |
| 01AAFA01 | 256 | 349 | 312 | 2   |
| 01AAFA02 | 132 | 156 | 134 | 1   |
| 01AAFA03 | 182 | 229 | 221 | 0   |
| 01AAFA04 | 0 | 0 | 0 | 0   |
| 01AAFA05 | 272 | 327 | 304 | 0   |

Things to note:
- The first column *must* be called "GeographyCode".
- You can have any number of columns (but for each column you have, the processing will take longer).
- Attribute column names need to be less than 10 characters to support the shapefile format.

## Running the Code

**_Needs to be updated for new process_**

Update lines 56-62 to update year and grids.
I usually run line 56 (read in attributes) to check field names are all correct.

Run code in file (analysis-no-overlay.R)

Check output
- include output file names in data summary
- File output in directory structure
