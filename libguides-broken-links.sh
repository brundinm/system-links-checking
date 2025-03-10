#!/usr/bin/bash

# MRB -- Sat 28-Dec-2024

# Purpose: Shell script to process LibGuides content to identify any broken
# links

# Description: Bash shell script to first run LinkChecker to process the
# LibGuides guide URLs obtained from the XML sitemap to output a file of
# broken links, and then post process the broken links output file to form a
# broken links report in a CSV tab-delimited format.  Then use a LibGuides
# mappings file to run an operation to add a new field to the broken links
# report that contains the guide name for each broken link record.

# To run the script, type the following at the command prompt:

#     bash libguides-broken-links.sh

# Notes:
# (1) In addition to the standard Unix utilities, this script requires that
# LinkChecker (https://linkchecker.github.io/linkchecker/) be installed.
# (2) You need to put the "libguides-mappings.tsv" mappings file in the same
# directory as this "libguides-broken-links.sh" script file; this mappings file
# is a helper file that is used to provide the guide name of the parent page
# that contains the broken link.  Over time, you can periodically check to see
# if the "libguides-broken-links.tsv" mappings file needs to be revised by
# reviewing both the subject guides page at
# "https://libguides.macewan.ca/" and the XML sitemap page at
# "https://libguides.macewan.ca/sitemap.xml" -- there are currently 73
# published guides that are listed in the mappings file.
# (3) The LibGuides broken links tab-delimited file
# "libguides-broken-links.csv" from the script output can be either pasted or
# imported into an Excel spreadsheet, and then sorted and styled as desired.
# (4) The LinkChecker command is formulated to log only errors, but you can
# change the "--no-warnings" option to "--verbose" to log all links, which
# include valid, warnings, and errors links; removing the "--no-warnings"
# option will log both errors and warnings.
# (5) The types of HTTP status code errors in column 4 "result" of the
# "dspace-broken-links.csv" file that reliably tend to indicate a broken
# link include 404 (404, 404 Not found, 404 OK, 404 Page not found: [. . .],
# 404 The requested content does not exist, 404 Unknown site), 409 (409
# Conflict), 410 (410 Gone), and 500 (500 Internal Server Error).  Other error
# messages that usually indicate a broken link are ConnectionError:
# HTTPConnectionPool [. . .], ConnectTimeout: HTTPConnectionPool [. . .],
# SSLError: HTTPSConnectionPool [. . .], and URL host '[. . .]' has invalid
# port.

####

####
# Function to check for broken links in the LibGuides published guides.  Use
# the LinkChecker link validator to check the links in LibGuides guides using
# the XML sitemap located at "https://libguides.macewan.ca/sitemap.xml" to
# identify any broken links in each guide and write out to the CSV file
# "broken-links.csv".  Then post process the "broken-links.csv" file to create
# a valid CSV file by removing newline characters that are not at the end of a
# record, deleting comment lines, and changing the field delimiters from
# semicolons to tabs to facilitate easier pasting of the output data into a
# Microsoft Excel spreadsheet.
function check_links() {

    # Check if the needed helper file "libguides-mappings.tsv" exists in the
    # script directory, and if it does not exist, display a warning message
    # and exit the script
    if [ ! -f libguides-mappings.tsv ]; then
        echo -e 'The required helper file "libguides-mappings.tsv" was not found in this directory!\n'
        exit 1
    fi

    # Print processing statement
    echo -e "Beginning process to get LibGuides guide broken links by conducting LinkChecker crawls . . .\n"

    # Use the LinkChecker link validator to crawl LibGuides using the list of
    # LibGuides guide URLs contained in the XML sitemap seed URL of
    # "https://libguides.macewan.ca/sitemap.xml" to identify any broken links
    # for each guide and write out to the CSV file "broken-links.csv"
    linkchecker --no-robots --no-warnings --check-extern -o csv --user-agent "User-Agent: LinkChecker: MacEwan University Library links checking operation" --ignore-url ^https:\/\/code\.jquery\.com\/.*$ --ignore-url ^https:\/\/creativecommons\.org\/.*$ --ignore-url ^https:\/\/d1qywhc7l90rsa\.cloudfront\.net\/.*$ --ignore-url ^https:\/\/fonts\.googleapis\.com\/.*$ --ignore-url ^https:\/\/libapps\-ca\.s3\.amazonaws\.com\/.*$ --ignore-url ^https:\/\/library\.macewan\.ca\/library\-copyright\-statement$ --ignore-url ^https:\/\/library\.macewan\.ca\/sites\/default\/files\/images\/by\-nc\.png$ --ignore-url ^https:\/\/library\.macewan\.ca\/sites\/default\/files\/images\/MacEwan_University_Library_Banner_88\.png$ --ignore-url ^https:\/\/library\.macewan\.ca\/research\-basics$ --ignore-url ^https:\/\/macewan\.libapps\.com\/.*$ --ignore-url ^https:\/\/netdna\.bootstrapcdn\.com\/.*$ --ignore-url ^https:\/\/static\-assets\-ca\.libguides\.com\/.*$ --ignore-url ^mailto:.*$ https://libguides.macewan.ca/sitemap.xml > broken-links.csv

    # Post process the LinkChecker output file to get a valid CSV file
 
    # Remove newlines and replace with a space if the newline character is
    # preceded by a period; this removes non-end-of-record newline characters
    # in the "warningstring" field
    perl -i -p -e 's/\.\n/\. /' broken-links.csv

    # Remove comment lines
    sed -i '/^# .*$/d' broken-links.csv

    # Change the field/column separators from semicolons to tabs; uses the FPAT
    # variable to properly process double quotation marks around a field if 
    # there is a semicolon in the field string
    gawk -v FPAT='"[^"]*"|[^;]*' -v OFS='\t' '{$1=$1} 1' broken-links.csv > broken-links-tabs.csv

}

####
# Function to add a new field containing the guide name.  Post process the
# LinkChecker broken links report file to output the parent URL of the page
# containing the broken link.  Then process this parent URL file to trim the
# URL to the base page URL for the guide, and then use the
# "libguides-mappings.tsv" file to replace the URL with the guide name.  Then
# add this file of guide names as a new first field in the LinkChecker broken
# links report file, and then switch the order of fields 2 and 3, and delete
# field 4.
function add_field() {

    # Post process the LinkChecker output file to add the guide name as a new
    # first field in each broken link record

    # Delete the "broken-links.csv" file, and then rename the file
    # "broken-links-tabs.csv" to "broken-links.csv"
    rm -f broken-links.csv && mv broken-links-tabs.csv broken-links.csv

    # Print out the second field of the "broken-links.csv" file which contains
    # the URL of the parent page with the broken link
    gawk -F'\t' -v OFS='\t' '{print $2}' broken-links.csv > base-urls.txt

    # Trim the URL string to the base page URL for real URLs
    sed -i 's/\(^https:\/\/libguides\.macewan\.ca\/c\.php?g=[0-9]*\)&p=.*$/\1/g' base-urls.txt

    # Trim the URL string to the base page URL for alias URLs
    sed -i 's/\(^https:\/\/libguides\.macewan\.ca\/[a-zA-Z0-9_-]*\)\/.*$/\1/g' base-urls.txt

    # Using the "libguides-mappings.tsv" file, replace each real URL with the
    # corresponding guide name
    gawk -F'\t' -v OFS='\t' 'FNR==NR{a[$1]=$3;next} {if ($1 in a){$1=a[$1]}; print $0}' libguides-mappings.tsv base-urls.txt > guide-names-temp.txt

    # Using the "libguides-mappings.tsv" file, replace each alias URL with the
    # corresponding guide name
    gawk -F'\t' -v OFS='\t' 'FNR==NR{a[$2]=$3;next} {if ($1 in a){$1=a[$1]}; print $0}' libguides-mappings.tsv guide-names-temp.txt > guide-names.txt

    # Merge the "guide-names.txt" file with the "broken-links.csv" file to add
    # a new first field containing the guide name
    paste -d '\t' guide-names.txt broken-links.csv > broken-links-temp.csv

    # Switch the order of fields 2 and 3, and delete field 4
    gawk -F'\t' -v OFS='\t' '{print $1, $3, $2, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18}' broken-links-temp.csv > libguides-broken-links.csv

    # Remove data processing files
    rm -f base-urls.txt broken-links.csv broken-links-temp.csv guide-names.txt guide-names-temp.txt

    # Print processing statement
    echo -e '\nFinished creating a tab-delimited file of LibGuides broken links called "libguides-broken-links.csv"\n'

    # Print final processing statement
    echo 'The LibGuides broken links processing operation is now finished!'

}

####
# Wrapper function to control program flow and logic.  Calls each function
# sequentially to first check for broken links for each published guide, and
# then add a new first field that contains the guide name of the page with the
# the broken link.  Neither of the functions takes any parameters or has any
# return values, but they both write to standard output which is redirected to
# files.
function main() {

    check_links
    add_field

}

main
