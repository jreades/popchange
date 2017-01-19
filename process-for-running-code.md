#Process for Generating Grids

These scripts allow you to take any census attribute for any census year (1971 - 2011) and convert it to a regular 1km grid across Great Britain. A number of steps have already been completed for you or you can do all the steps manually yourself.
 
This outlines the inputs required for the basic analysis:

##Download Census data

Prepare the Census data you wish to use. An example of this file is OA_attributes.csv / OA_1991_attributes.csv. This is a CSV file containing a list of all the OAs or EDs (depending on the census year) and the one or more attributes you wish to create a grid for. One grid will be created for each attribute you enter. For example:

GeographyCode | AllPresRes | TotalPop | EtWh | EtBlCab
01AAFA01 | 256 | 349 | 312 | 2
01AAFA02 | 132 | 156 | 134 | 1
01AAFA03 | 182 | 229 | 221 | 0
01AAFA04 | 0 | 0 | 0 | 0
01AAFA05 | 272 | 327 | 304 | 0

Things to note:
- The first column *must* be called "GeographyCode". 
- You can have any number of columns (but for each column you have, the processing will take longer).
- Attribute column names need to be less than 10 characters to support the shapefile format.

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

##Update & Run Code

Update lines 56-62 to update year and grids. 
I usually run line 56 (read in attributes) to check field names are all correct. 

Run code in file (analysis-no-overlay.R)

Check output
- include output file names in data summary
- File output in directory structure
