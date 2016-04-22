Process

Download data 

- Casweb (1971 - 2001)
- - For 2001, you need to do England, Scotland and Wales separately and combine them into one file (usually the variable structure matches for England and Wales, and is similar for Scotland). 
- - For 1991, some tables are structured differently and so you need to download separately and combine them as above. 
- - For 1971, need to run code to allocate 71 EDs to 81 EDs As per script. 

- For 2011
- - England download from Nomis (https://www.nomisweb.co.uk/census/2011/bulk/r2_2) for England and Wales
- - Scotland download from Scotland Census (http://www.scotlandscensus.gov.uk/ods-web/data-warehouse.html#bulkdatatab)
- - Some Scotland variables are ordered very differently (e.g. Country of Birth & Ethnicity). Combine these carefully!
- - Also replace '- 'in Scotland 11 with '0'. This is easiest done in TextWrangler than LibreOffice Calc.)

Add into data-summary.xlsx

Work out field names (max 8 characters)
- Copy field names into input data file.

Update lines 56-62 to update year and grids. 
I usually run line 56 (read in attributes) to check field names are all correct. 

Run code

Check output
- include output file names in data summary
- File output in directory structure
