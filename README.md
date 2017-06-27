# PopChange (v2)
PopChange: Enabling Small Area Comparisons of Census Data since 1971 for Great Britian

This forked repo contains updated R code to process and generate a regular grid of arbitrary size from the original Census geographies (Output Areas [OAs] or Enumeration Districts [EDs]) to enable comparisons of variables between two or more Census years between 1971 and 2011.

Please note that being _able_ to compare any set of Census years does not mean that the variables are necessarily comparable _even if they share the same name_. You will need to look at the gory details of Census questions and coding in order to ascertain how effectively a comparison can be made.

The original [project website](https://www.liverpool.ac.uk/geography-and-planning/research/popchange/introduction/) contains more information on the research project including current research papers.

## Why Fork?

The original project was based on a mixed workflow incorporating both FOSS (R) and proprietary software (ArcGIS), and both open and closed data. Some steps, such as the creation of a grid in ArcGIS are either not automated, or only automated within the Model Builder and, as such, place a licensing or access burden on the user.

The forked repo is designed to support full replication using _**only**_ open code and open data. It is also intended to offer more flexibility in grid creation (not just the default value of 1km * 1km or the anticipated higher-res grid [for London] of 100m * 100m). To understand more about this read on...

## Generating Your Own Grids

For more detail about how to use the code to generate your own grids, please see: [CODE.md](CODE.md).

**_Note:_** Processing all of the raw data for these will consume roughly 50GB of diskspace. This consumption arises primarily because of the intermediate outputs associated with the OSM data: they permit greater flexibility in weighting and auditability but at the cost of higher levels of diskspace usage.

But here is the general overview:

### Getting the Code 

Clone or download the repo to somewhere easy to find.

### Create the Directory Structure 

Under the `popchange` directory the `setup.R` script will create a set of data directories; these are not found in git because of the volumes associated with extracting and processing OSM, OS & NSPL features.

### Downloading the Open Data

All of these except OS OpenRoads _should_ be downloadable via the `setup.R` script. After that you will need to run `ni-preprocessing.R` _once_ to set up the country file correctly to include Northern Ireland as an iterable option.

The sources (in case the direct URL changes) are:
* The 100km OS shapefile tiles (so all five files, but easiest to download the Zipfile) from [github.com/charlesroper](https://github.com/charlesroper/OSGB_Grids)
* England OSM (> 700MB): [england-latest.osm.pbf](http://download.geofabrik.de/europe/great-britain/england-latest.osm.pbf)
* Scotland OSM (> 100MB): [scotland-latest.osm.pbf](http://download.geofabrik.de/europe/great-britain/scotland-latest.osm.pbf)
* Wales OSM (> 50MB): [wales-latest.osm.pbf](http://download.geofabrik.de/europe/great-britain/wales-latest.osm.pbf)
* Northern Ireland / Ireland OSM (> 125MB): [ireland-and-northern-ireland-latest.pbf](http://download.geofabrik.de/europe/ireland-and-northern-ireland-latest.osm.pbf)
* Admin boundaries: [Regions 2016 Generalised Clipped Boundaries in England](http://geoportal.statistics.gov.uk/datasets/regions-december-2016-generalised-clipped-boundaries-in-england)
* Country boundaries: [Countries 2016 Generalised Clipped Boundaries in Great Britain](http://geoportal.statistics.gov.uk/datasets/countries-december-2016-generalised-clipped-boundaries-in-great-britain)
* NSPL data: [National Statistics Postcode Lookup (May 2017)](http://ons.maps.arcgis.com/home/item.html?id=56a02541d9ab42fc88f18bfb8543765e) (Will need to be updated periodically, though not perhaps before the 2021 Census...)
* NI boundaries: [OSNI Open Data Largescale Boundaries - NI Outline](http://osni-spatial-ni.opendata.arcgis.com/datasets/d9dfdaf77847401e81efc9471dcd09e1_0) (subject to change, I'd expect)
* OSNI Roads: [OSNI Open Data - 50k Transport Line](http://osni-spatial-ni.opendata.arcgis.com/datasets/f9b780573ecb446a8e7acf2235ed886e_2) (subject to change, I'd expect)
* OS OpenRoads: [OS OpenData Products](https://www.ordnancesurvey.co.uk/opendatadownload/products.html)

### Running the Code to Enable Population Gridding

Run the scripts in the following order to set up all of the data needed to actually do population allocations:

1. `00_setup.R` (to set up the data directories)
2. `01_preprocessing.R`
3. `02_grid.R`
4. `03_roads.R`
5. `04_nspl.R`
6. `05_osm.R`
7. `assemble.R`
8. `allocate.R`
  
# Notes for Improvements

These are 'notes to self' on larger issues not yet fully addressed but which would streamline and/or improve the allocation process.

## OSM-to-Bash Script

Based on some issues I'm having with R/R-Studio with the `osm.R` file and long-running `system2` calls, my guess is that R has some kind of timeout on unix commands. A better long-term approach would, instead of having commands fired off from R, be to have R write a shell script that is fired at the end of the R file. That would be (oddly) more robust agains the timeouts *and* it would make auditing/re-running code a bit easier.

## Parallelisation

This whole thing is ripe for parallelisation: it's possible to break up the work by region (i.e. Scotland, Wales, NI, London, Southeast of England, etc.), and each of these can then be broken down (the road processing can happen at the same time as the NSPL processing), and some of _these_ are further broken down using the grid. In particular, the only effective way to handle joining the OSM data to the grid was to take about 100^2 cells at a time (with a 250m cell size) and chop out the matching part of the merged OSM file. Trying to do it as one big join hadn't returned after 8 hours of processing time!