#!/usr/bin/bash

# MRB -- Sat 28-Dec-2024

# Purpose: Shell script to process DSpace item content to identify any broken
# links

# Description: Bash shell script to first query DSpace using the OAI-PMH API
# using two cURL commands in a FOR loop to retrieve the MODS metadata, then
# pipe to an XMLStarlet select command to filter out the DSpace item
# Handle.Net URIs, then pipe to a filter to make them DSpace Handle URIs and
# write out to a file.  Then run a Lynx command in a WHILE loop using the
# DSpace URIs to return messages containing the redirected DSpace item URLs,
# and then pipe to a filter to correctly formulate the DSpace URLs and write
# out to a file.  Then run LinkChecker in a WHILE loop using the DSpace item
# URLs to output a file of broken links, and then post process the broken links
# output file to form a broken links report in a CSV tab-delimited format.

# To run the script, type the following at the command prompt:

#     bash dspace-broken-links.sh

# Notes:
# (1) In addition to the standard Unix utilities, this script requires that
# LinkChecker (https://linkchecker.github.io/linkchecker/), Lynx
# (https://lynx.invisible-island.net/), and XMLStarlet
# (https://xmlstar.sourceforge.net/) be installed.
# (2) Because of the architecture and structure of the DSpace web site, it is
# not possible to provide a single seed URL to a link checker application and
# have it crawl the site checking for broken links; consequently, the approach
# adopted is to obtain all of the DSpace item URLs and have the LinkChecker
# application crawl each DSpace item link individually and check the links on
# each DSpace item page.
# (3) The DSpace item URIs need to be converted to DSpace item URLs because
# there are two redirects, from the Handle.Net URI to the DSpace Handle URI to
# the resulting DSpace item URL, and all link checkers terminate a link crawl
# after checking a redirect, similar to to how they terminate after checking an
# external link.
# (4) The DSpace broken links tab-delimited file "dspace-broken-links.csv" from
# the script output can be either pasted or imported into an Excel
# spreadsheet, and then sorted and styled as desired.
# (5) The LinkChecker command is formulated to log only errors, but you can
# change the "--no-warnings" option to "--verbose" to log all links, which
# include valid, warnings, and errors links; removing the "--no-warnings"
# option will log both errors and warnings.
# (6) The types of HTTP status code errors in column 4 "result" of the
# "dspace-broken-links.csv" file that reliably tend to indicate a broken
# link include 404 (404, 404 Not found, 404 OK, 404 Page not found: [. . .],
# 404 The requested content does not exist, 404 Unknown site), 409 (409
# Conflict), 410 (410 Gone), and 500 (500 Internal Server Error).  Other error
# messages that usually indicate a broken link are ConnectionError:
# HTTPConnectionPool [. . .], ConnectTimeout: HTTPConnectionPool [. . .],
# SSLError: HTTPSConnectionPool [. . .], and URL host '[. . .]' has invalid
# port.
# (7) Over time, you can periodically run an initial OAI-PMH query in a
# browser to see if the $TOTAL_QUERIES constant needs to be increased -- it is
# presently 37, to accommodate 3,628 OAI-PMH records that are retrieved in
# 100-record increments.  A sample DSpace OAI-PMH browser query is the
# following: https://roam.macewan.ca/server/oai/request?verb=ListRecords&
# metadataPrefix=mods
# (8) Instead of installing and using the XMLStarlet toolkit, you can use the
# xmllint command-line utility, which is usually already installed in every
# Unix-like system as part of the libxml2 software library.  The xmllint
# command to replace the XMLStarlet command to parse the OAI-PMH XML output to
# retrieve the Handle.Net URIs is the following: xmllint --xpath
# '/*[local-name()="OAI-PMH"]/*[local-name()="ListRecords"]/*[local-name()
# ="record"]/*[local-name()="metadata"]/*[local-name()="mods"]/*[local-name()
# ="identifier"][@type="uri"]/text()'  Similarly, if you don't want to install
# and use the command-line Lynx browser, you can replace the Lynx, grep, and
# cut piped command with this cURL command: curl -H "User-Agent: cURL: MacEwan
# University Library links checking operation" -w "%{redirect_url}\n"
# --max-redirs 1 -I -s -S -o /dev/null $uri
# (9) This shell script can be tested using a small sample of 200 OAI-PMH
# records (as opposed to the full record set of 3,628 OAI-PMH records) by
# temporarily changing the $TOTAL_QUERIES constant from 37 to 2, which will
# test all processing instructions, including all loops and conditional
# branches.  As well, you can also uncomment the line just below the FOR loop
# in the get_uris() function to test the shell script using only the first 10
# OAI-PMH records.

####

####
# Function to get the DSpace Handle URIs for the DSpace items.  In a FOR loop,
# use two cURL queries to retrieve OAI-PMH MODS records in 100-record
# increments, then pipe to the XMLStarlet toolkit to run an XMLStarlet select
# command to parse out the Handle.Net URIs from the MODS identifier elements,
# and then pipe to a filter to reformulate the Handle.Net URIs to DSpace
# Handle URIs and write out to the file "dspace-uris.txt".
function get_uris() {

    # Run two cURL commands in a FOR loop to query the DSpace OAI-PMH API to
    # retrieve OAI-PMH records and save DSpace Handle URIs to the file
    # "dspace-uris.txt"

    # Note: there are currently 3,628 OAI-PMH records, and since each query
    # result set is 100 records, we therefore need 37 100-record sets
    
    # Declare variables
    declare -r TOTAL_QUERIES=37 # Can change to 2 to test the script
    declare -i query_number=1
    declare -i record_number=0

    # Print processing statement
    echo -e "Beginning process to get DSpace Handle URIs by conducting $TOTAL_QUERIES cURL queries . . .\n"

    for i in $(seq 1 $TOTAL_QUERIES); do
        if [ $query_number -eq 1 ]; then
            # Query the DSpace OAI-PMH API to retrieve the first 100 OAI-PMH
            # records and save the DSpace Handle URIs to the file
            # "dspace-uris.txt"
            curl -H "User-Agent: cURL: MacEwan University Library links checking operation" -sS 'https://roam.macewan.ca:8443/server/oai/request?verb=ListRecords&metadataPrefix=mods' | xmlstarlet sel -N oai="http://www.openarchives.org/OAI/2.0/" -N mods="http://www.loc.gov/mods/v3" -t -v '/oai:OAI-PMH/oai:ListRecords/oai:record/oai:metadata/mods:mods/mods:identifier[@type="uri"]/text()' -n | sed 's|https://hdl.handle.net/|https://roam.macewan.ca/handle/|g' > dspace-uris.txt
        else
            # Query the DSpace OAI-PMH API to retrieve the OAI-PMH records
            # after the 100th record in 100-record increments and append the
            # DSpace Handle URIs to the file "dspace-uris.txt"
            curl -H "User-Agent: cURL: MacEwan University Library links checking operation" -sS "https://roam.macewan.ca:8443/server/oai/request?verb=ListRecords&resumptionToken=mods////$record_number" | xmlstarlet sel -N oai="http://www.openarchives.org/OAI/2.0/" -N mods="http://www.loc.gov/mods/v3" -t -v '/oai:OAI-PMH/oai:ListRecords/oai:record/oai:metadata/mods:mods/mods:identifier[@type="uri"]/text()' -n | sed 's|https://hdl.handle.net/|https://roam.macewan.ca/handle/|g' >> dspace-uris.txt
        fi
        echo "Finished cURL query number $query_number of $TOTAL_QUERIES"
        # Increment variables
        query_number=$((query_number + 1))
        record_number=$((record_number + 100))
        sleep 0.5s
    done

    # Print processing statement
    echo -e '\nFinished creating a file of DSpace Handle URIs called "dspace-uris.txt"\n'

    # Uncomment the line below if you want to test the script using only the
    # first 10 OAI-PMH records; note: you might want to also change the
    # LinkChecker command option from "--no-warnings" to "--verbose" to ensure
    # that there is some LinkChecker output
    #sed -i '11,$d' dspace-uris.txt

}

####
# Function to get the URLs for the DSpace items.  In a WHILE loop, use the
# Lynx web browser to search DSpace using the list of DSpace Handle URIs
# contained in the file "dspace-uris.txt" to output Lynx messages containing
# the redirected DSpace item URLs, and then pipe to a filter to get the DSpace
# item URLs and write out to the file "dspace-urls.txt".
function get_urls() {

    # Run a Lynx command in a WHILE loop to search DSpace using DSpace Handle
    # URIs and save the DSpace item URLs to the file "dspace-urls.txt"

    # Declare variables
    declare -r TOTAL_SEARCHES="$(cat dspace-uris.txt | wc -l)"
    declare -i search_number=1

    # Print processing statement
    echo -e "Beginning process to get DSpace item URLs by conducting $TOTAL_SEARCHES Lynx searches . . .\n"

    while read -r line; do
        # Declare variable
        declare +i uri="$line"
        lynx -dump -listonly -noredir -useragent="User-Agent: Lynx: MacEwan University Library links checking operation" $uri | grep 'https:\/\/roam\.macewan\.ca\/items\/' | cut -c 7- >> dspace-urls.txt
        echo "Finished Lynx search number $search_number of $TOTAL_SEARCHES"
        # Increment variable
        search_number=$((search_number + 1))
        sleep 0.5s
    done < "dspace-uris.txt"

    # Print processing statement
    echo -e '\nFinished creating a file of DSpace item URLs called "dspace-urls.txt"\n'

}

####
# Function to check for broken links for the DSpace items.  In a WHILE loop,
# use the LinkChecker link validator to crawl DSpace using the list of DSpace
# item URLs contained in the file "dspace-urls.txt" to identify any broken
# links for each DSpace item and write out to the CSV file
# "dspace-broken-links.csv"; post process the "dspace-broken-links.csv" file
# to create a valid CSV file by removing newline characters that are not at
# the end of a record, deleting comment lines, deleting multiple "header"
# lines, adding a header line, and changing the field delimiters from
# semicolons to tabs to facilitate easier pasting of the output data into a
# Microsoft Excel spreadsheet.
function check_links() {

    # Run a LinkChecker command in a WHILE loop to crawl DSpace using DSpace
    # item URLs to output any broken links for each DSpace item to the file
    # "broken-links.csv"

    # Declare variables
    declare -r TOTAL_CRAWLS="$(cat dspace-urls.txt | wc -l)"
    declare -i crawl_number=1

    # Print processing statement
    echo -e "Beginning process to get DSpace item broken links by conducting $TOTAL_CRAWLS LinkChecker crawls . . .\n"

    while read -r line; do
        # Declare variable
        declare +i url="$line"
        linkchecker --no-robots --no-warnings --no-status --check-extern -o csv --user-agent "User-Agent: LinkChecker: MacEwan University Library links checking operation" --ignore-url ^https:\/\/creativecommons\.org\/.*$ --ignore-url ^https:\/\/hdl\.handle\.net\/20\.500\.14078\/.*$ --ignore-url ^https:\/\/library\.macewan\.ca\/$ --ignore-url ^https:\/\/macewan\.ca\/$ --ignore-url ^https:\/\/roam\.macewan\.ca\/.*$ --ignore-url ^https:\/\/schema\.org\/.*$ --ignore-url ^https:\/\/www\.macewan\.ca\/about\-macewan\/research\/$ --ignore-url ^javascript:void\(0\)$ --ignore-url ^mailto:roam\@macewan\.ca$ $url >> broken-links.csv
        echo "Finished LinkChecker crawl number $crawl_number of $TOTAL_CRAWLS"
        # Increment variable
        crawl_number=$((crawl_number + 1))
        sleep 0.5s
    done < "dspace-urls.txt"

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
    gawk -v FPAT='"[^"]*"|[^;]*' -v OFS='\t' '{$1=$1} 1' broken-links.csv > dspace-broken-links.csv
    
    # Remove multiple "header" rows
    sed -i '/^urlname\tparentname\tbase\tresult\twarningstring\tinfostring\tvalid\turl\tline\tcolumn\tname\tdltime\tsize\tchecktime\tcached\tlevel\tmodified$/d' dspace-broken-links.csv

    # Add a header row
    sed -i '1 i\urlname\tparentname\tbase\tresult\twarningstring\tinfostring\tvalid\turl\tline\tcolumn\tname\tdltime\tsize\tchecktime\tcached\tlevel\tmodified' dspace-broken-links.csv

    # Remove data processing files
    rm -f broken-links.csv dspace-uris.txt dspace-urls.txt

    # Print processing statement
    echo -e '\nFinished creating a tab-delimited file of DSpace broken links called "dspace-broken-links.csv"\n'

    # Print final processing statement
    echo 'The DSpace broken links processing operation is now finished!'

}

####
# Wrapper function to control program flow and logic.  Calls each function
# sequentially to first get the item URIs, then get the item URLs, and then
# check for broken links for each item URL.  None of the functions take any
# parameters or have any return values, but they all write to standard output
# which is redirected to files.
function main() {

    get_uris
    get_urls
    check_links

}

main
