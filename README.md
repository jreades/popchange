# PopChange (v2)
PopChange: Enabling Small Area Comparisons of Census Data since 1971 for Great Britian

This forked repo contains updated R code to process and generate a regular grid of arbitrary size from the original Census geographies (Output Areas [OAs] or Enumeration Districts [EDs]) to enable comparisons of variables between two or more Census years between 1971 and 2011.

Please note that being _able_ to compare any set of Census years does not mean that the variables are necessarily comparable _even if they share the same name_. You will need to look at the gory details of Census questions and coding in order to ascertain how effectively a comparison can be made.

The original [project website](https://www.liverpool.ac.uk/geography-and-planning/research/popchange/introduction/) contains more information on the research project including current research papers.

## Why Fork?

The original project was based on a mixed workflow incorporating both FOSS (R) and proprietary software (ArcGIS), and both open and closed data. Some steps, such as the creation of a grid in ArcGIS are either not automated, or only automated within the Model Builder and, as such, place a licensing or access burden on the user.

The forked repo is designed to support full replication using _**only**_ open code and open data. It is also intended to offer more flexibility in grid creation (not just the default value of 1km * 1km or the anticipated higher-res grid [for London] of 100m * 100m). To understand more about this read on...

## Generating Your Own Grids

For information on how to use the code to generate your own grids, please see: [CODE.md](CODE.md).

# Notes for Improvements

These are 'notes to self' on larger issues not yet fully addressed but which would streamline and/or improve the allocation process.

## OSM-to-Bash Script

Based on some issues I'm having with R/R-Studio and long-running system2 calls, my guess is that R has some kind of timeout on unix commands. A better long-term approach would, instead of having commands fired off from R, have R write a shell script that is fired at the end of the R script. That would be (oddly) more robust agains the timeouts *and* it would make auditing/re-running code a bit easier.

## Line Features in OSM

Current, we only process polygon features from the OSM data files, so this excludes rivers and roads from our grid weighting process. Somehow OSM 'knows' how to render river and road widths from the centreline, but I can't quite figure it out (yet). So we need to think what could be done with line features (roads and large rivers) to help suppress 'non-buildable' areas.
