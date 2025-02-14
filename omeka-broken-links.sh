#!/usr/bin/bash

# MRB -- Sat 28-Dec-2024

# Purpose: Shell script to process Omeka content to identify any broken links

# Description: Bash shell script to run LinkChecker to process the Omeka URLs
# to output a file of broken links, and then post process the broken links
# output file to form a broken links report in a CSV tab-delimited format.

# To run the script, type the following at the command prompt:

#     bash omeka-broken-links.sh

# Notes:
# (1) In addition to the standard Unix utilities, this script requires that
# LinkChecker (https://linkchecker.github.io/linkchecker/) be installed.
# (2) The Omeka broken links tab-delimited file "omeka-broken-links.csv" from
# the script output can be either pasted or imported into an Excel
# spreadsheet, and then sorted and styled as desired.
# (3) The LinkChecker command is formulated to log only errors, but you can
# change the "--no-warnings" option to "--verbose" to log all links, which
# include valid, warnings, and errors links; removing the "--no-warnings"
# option will log both errors and warnings.
# (4) The types of HTTP status code errors in column 4 "result" of the
# "dspace-broken-links.csv" file that reliably tend to indicate a broken
# link include 404 (404, 404 Not found, 404 OK, 404 Page not found: [. . .],
# 404 The requested content does not exist, 404 Unknown site), 409 (409
# Conflict), 410 (410 Gone), and 500 (500 Internal Server Error).  Other error
# messages that usually indicate a broken link are ConnectionError:
# HTTPConnectionPool [. . .], ConnectTimeout: HTTPConnectionPool [. . .],
# SSLError: HTTPSConnectionPool [. . .], and URL host '[. . .]' has invalid
# port.

####

# Print processing statement
echo -e "Beginning process to get Omeka broken links by conducting LinkChecker crawls . . .\n"

# Use the LinkChecker link validator to crawl Omeka using the seed URL of
# https://digitalexhibits.macewan.ca/ to identify any broken links on the site
# and write out to the CSV file "broken-links.csv"
linkchecker --no-robots --no-warnings --check-extern -o csv --user-agent "User-Agent: LinkChecker: MacEwan University Library links checking operation" --ignore-url ^https:\/\/code\.jquery\.com\/.*$ --ignore-url ^https:\/\/creativecommons\.org\/.*$ --ignore-url ^https:\/\/digitalexhibits\.macewan\.ca\/application\/.*$ --ignore-url ^https:\/\/digitalexhibits\.macewan\.ca\/files\/.*$ --ignore-url ^https:\/\/digitalexhibits\.macewan\.ca\/oembed.*$ --ignore-url ^https:\/\/fonts\.googleapis\.com\/.*$ --ignore-url ^mailto:.*$ https://digitalexhibits.macewan.ca/ > broken-links.csv

# Post process the LinkChecker output file to get a valid CSV file

# Remove newlines and replace with a space if the newline character is
# preceded by a period; this removes non-end-of-record newline characters in
# the "warningstring" field
perl -i -p -e 's/\.\n/\. /' broken-links.csv

# Remove comment lines
sed -i '/^# .*$/d' broken-links.csv

# Change the field/column separators from semicolons to tabs; uses the FPAT
# variable to properly process double quotation marks around a field if there
# is a semicolon in the field string
gawk -v FPAT='"[^"]*"|[^;]*' -v OFS='\t' '{$1=$1} 1' broken-links.csv > omeka-broken-links.csv

# Remove data processing file
rm -f broken-links.csv

# Print processing statement
echo -e '\nFinished creating a tab-delimited file of Omeka broken links called "omeka-broken-links.csv"\n'

# Print final processing statement
echo 'The Omeka broken links processing operation is now finished!'
