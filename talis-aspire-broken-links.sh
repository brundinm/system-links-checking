#!/usr/bin/bash

# MRB -- Sat 28-Dec-2024

# Purpose: Shell script to process Talis Aspire content to identify any broken
# links

# Description: Bash shell script to first use a WHILE loop to identify the
# Talis Aspire items that have external web addresses, and then output the
# links and attendant metadata into two files.  Then run a LinkChecker command
# using the Talis Aspire links file to output a file of broken links, and then
# post process the broken links output file to form a valid CSV file.  Then run
# a match and merge operation on the metadata file and the broken links file to
# join each broken link with the Talis Aspire items and lists metadata that
# are associated with that link to form a broken links report in a CSV
# tab-delimited format.

# To run the script, type the following at the command prompt:

#     bash talis-aspire-broken-links.sh

# Notes:
# (1) In addition to the standard Unix utilities, this script requires that
# LinkChecker (https://linkchecker.github.io/linkchecker/) be installed.
# (2) In Talis Aspire, run the "All List Items" report, and select and apply
# the filters of "List Status" being "Published" and "Time Period" being the
# term you are interested in, e.g., "Winter 2025".  Then use the "Export to
# CSV" button option in the upper right of the page to have a download link
# emailed to you.  Then download the CSV file, make a copy of the CSV file and
# name it "all-list-items.csv", and then put the "all-list-items.csv" file in
# the same directory as this "talis-aspire-broken-links.sh" script file.
# (3) Because of the architecture and structure of the Talis Aspire web site,
# it is not possible to provide a single seed URL to a link checker application
# and have it crawl the site checking for broken links; consequently, the
# approach adopted is to obtain all of the item web address links in a file
# and have the LinkChecker application check each link and then merge each
# identified broken link with the associated item and list metadata.
# (4) We need to determine in which items and lists a broken link is located
# in, so we run a match and merge operation between the Talis Aspire metadata
# with links, items, and lists metadata information, and the broken links
# output from the LinkChecker application, matching on the link URL.
# (5) The Talis Aspire broken links tab-delimited file
# "talis-aspire-broken-links.csv" from the script output can be either pasted
# or imported into an Excel spreadsheet, and then sorted and styled as desired.
# (6) The LinkChecker command is formulated to log only errors, but you can
# change the "--no-warnings" option to "--verbose" to log all links, which
# include valid, warnings, and errors links; removing the "--no-warnings"
# option will log both errors and warnings.
# (7) The types of HTTP status code errors in column 10 "result" of the
# "talis-aspire-broken-links.csv" file that reliably tend to indicate a broken
# link include 404 (404, 404 Not found, 404 OK, 404 Page not found: [. . .],
# 404 The requested content does not exist, 404 Unknown site), 409 (409
# Conflict), 410 (410 Gone), and 500 (500 Internal Server Error).  Other error
# messages that usually indicate a broken link are ConnectionError:
# HTTPConnectionPool [. . .], ConnectTimeout: HTTPConnectionPool [. . .],
# SSLError: HTTPSConnectionPool [. . .], and URL host '[. . .]' has invalid
# port.
# (8) Instead of using AWK commands with the FPAT variable (which defines the
# field pattern, as opposed to the field separator) to parse the input CSV file
# "all-list-items.csv", you could install a dedicated command-line CSV parser
# such as csvkit (https://github.com/wireservice/csvkit), Miller
# (https://github.com/johnkerl/miller), or xsv
# (https://github.com/BurntSushi/xsv).  For example, to extract fields 7, 3, 1,
# 6, and 25, from the comma-separated "all-list-items.csv" file and produce
# tab-separated output, you can use these csvcut and csvformat commands from
# the csvkit set of tools: csvcut -c "7,3,1,6,25" all-list-items.csv |
# csvformat -T > output.csv  And the Miller command to extract the same
# variables is the following: mlr --csv --ofs '\t' cut -f "List Link","Item
# Link","Title","List Appearance","Time Period" all-list-items.csv > output.csv
# And the xsv command to filter those same variables is this: xsv select "List
# Link","Item Link","Title","List Appearance","Time Period" all-list-items.csv
# | xsv fmt -t '\t' > output.csv
# (9) This shell script can be tested with a small sample of the first 10
# Talis Aspire items that also contain an external web link address by
# uncommenting the line near the beginning of the create_files() function.

####

####
# Function to create needed input files.  Use a WHILE loop and an IF-ELSEIF
# conditional construct to parse certain fields in the input file
# "all-list-items.csv" to identify if there is an external web address for the
# item, and then print out the web link to the file "talis-aspire-links.txt",
# as well as print out five fields of associated item and list metadata for
# that web link to the file "talis-aspire-metadata-temp.csv".  The web link
# for the item can be in any of the fields Web Address (24th field), Primary
# Web Address (36th field), or Online Resource Web Address (38th field).  The
# five fields of metadata are the fields Title (1st field), Item Link (3rd
# field), List Appearance (6th field), List Link (7th field), and Time Period
# (25th field).  Then merge the "talis-aspire-links.txt" file and the
# "talis-aspire-metadata-temp.csv" file to produce the merged file
# "talis-aspire-metadata.csv".  Then process the "talis-aspire-links.txt" file
# in a WHILE loop to produce an HTML links file called
# "talis-aspire-links.html".
function create_files() {
    
    # Check if the needed input file "all-list-items.csv" exists in the script
    # directory, and if it does not exist, display a warning message and exit
    # the script
    if [ ! -f all-list-items.csv ]; then
        echo -e 'The required input file "all-list-items.csv" was not found in this directory!\n'
        exit 1
    fi
    
    # Delete the first line header row
    sed -i '1d' all-list-items.csv
    
    # Uncomment the line below if you want to test the script using only 10
    # Talis Aspire item records that also have an external web link address;
    # note: after the deduping operation, the number of HTML links processed
    # might be less than 10 -- you might want to also change the LinkChecker
    # command option from "--no-warnings" to "--verbose" to ensure that there
    # is some LinkChecker output
    #cp all-list-items.csv all-list-items-temp.csv && gawk -v FPAT='[^,]*|"([^"]|"")*"' '!($24=="") {print $0}' all-list-items-temp.csv | sed '11,$d' > all-list-items.csv && rm all-list-items-temp.csv
    
    # Declare variables
    declare -r TOTAL_ITEMS="$(cat all-list-items.csv | wc -l)"
    declare -i item_number=1

    # Print processing statement
    echo -e "Beginning process to get Talis Aspire item links and other item metadata by processing $TOTAL_ITEMS items . . .\n"

    # Process the "all-list-items.csv" comma-separated CSV file to print out
    # the links and the associated metadata into two files; use the FPAT
    # variable in the AWK commands to properly parse the comma-separated
    # input file that also contains double quotation marks around a field if
    # there is a space or a comma in the field string
    while read -r line; do
        # Declare variables
        declare +i web_address="$(echo -e "$line" | gawk -v FPAT='[^,]*|"([^"]|"")*"' '{print $24}')"
        declare +i primary_web_address="$(echo -e "$line" | gawk -v FPAT='[^,]*|"([^"]|"")*"' '{print $36}')"
        declare +i online_resource_web_address="$(echo -e "$line" | gawk -v FPAT='[^,]*|"([^"]|"")*"' '{print $38}')"
        # Perform a conditional check to identify if there is an external web
        # link address for that item, and if there is, then print out the web
        # link URL into a file and the associated metadata into another file
        if [[ $web_address ]]; then
            echo "$web_address" >> talis-aspire-links.txt
            echo -e "$line" | gawk -v FPAT='[^,]*|"([^"]|"")*"' -v OFS='\t' '{print $7, $3, $1, $6, $25}' >> talis-aspire-metadata-temp.csv
        elif [[ $primary_web_address ]]; then
            echo "$primary_web_address" >> talis-aspire-links.txt
            echo -e "$line" | gawk -v FPAT='[^,]*|"([^"]|"")*"' -v OFS='\t' '{print $7, $3, $1, $6, $25}' >> talis-aspire-metadata-temp.csv
        elif [[ $online_resource_web_address ]]; then
            echo "$online_resource_web_address" >> talis-aspire-links.txt
            echo -e "$line" | gawk -v FPAT='[^,]*|"([^"]|"")*"' -v OFS='\t' '{print $7, $3, $1, $6, $25}' >> talis-aspire-metadata-temp.csv
        fi
        echo "Finished processing item number $item_number of $TOTAL_ITEMS"
        # Increment variable
        item_number=$((item_number + 1))
    done < "all-list-items.csv"

    # Convert the HTML entity or character reference "&amp;" to "&" so that
    # these links will correctly match with the LinkChecker output links
    # which convert "&amp;" to "&"; this is because LinkChecker uses a
    # semicolon as the field separator in the output
    sed -i 's/\&amp\;/\&/g' talis-aspire-links.txt

    # Remove the double quotation marks that are left from the double quoted
    # fields (i.e., double double quotation marks, e.g., ""string,here""),
    # which are used for the few cases that have multiple links for the field
    # entry, separated by semicolons
    sed -i 's/"//g' talis-aspire-links.txt

    # For the few cases where the field entry contains multiple links
    # separated by a semicolon, retain only the first listed link and remove
    # the trailing semicolon separator
    sed -i 's/\;.*$//g' talis-aspire-links.txt

    # Merge the links file with the metadata file
    paste -d '\t' talis-aspire-links.txt talis-aspire-metadata-temp.csv > talis-aspire-metadata.csv
    
    # Remove data processing files
    rm -f all-list-items.csv talis-aspire-metadata-temp.csv

    # Print processing statement
    echo -e '\nFinished creating a file of Talis Aspire item links called "talis-aspire-links.txt" and a file of item metadata called "talis-aspire-metadata.csv"\n'

    # Process Talis Aspire text links file to get an HTML file of links

    # Remove duplicate links
    cat talis-aspire-links.txt | sort | uniq > talis-aspire-links-deduped.txt

    # Use a WHILE loop to convert the text file into an HTML file of links
    
    # Declare variables
    declare -r TOTAL_LINKS="$(cat talis-aspire-links-deduped.txt | wc -l)"
    declare -i link_number=1

    # Print processing statement
    echo -e "Beginning process to create an HTML links file from the text links file by creating $TOTAL_LINKS links . . .\n"

    while read -r line; do
        # Declare variable
        declare +i link="$line"
        printf "<a href=\"$link\">$link</a><br />\n" >> talis-aspire-links.html
        echo Finished printing link $link_number of $TOTAL_LINKS
        # Increment variable
        link_number=$((link_number + 1)) ;
    done < "talis-aspire-links-deduped.txt"

    # Remove data processing files
    rm -f talis-aspire-links.txt talis-aspire-links-deduped.txt

    # Print processing statement
    echo -e '\nFinished creating a file of Talis Aspire item links called "talis-aspire-links.html"\n'

}

####
# Function to check for broken links for the Talis Aspire items.  Use the
# LinkChecker link validator to check the list of links in Talis Aspire items
# contained in the file "talis-aspire-links.html" to identify any broken links
# for each item and write out to the CSV file "broken-links.csv".  Then post
# process the "broken-links.csv" file to create a valid CSV file by removing
# newline characters that are not at the end of a record, deleting comment
# lines, deleting the second line that checks the input HTML file, and
# changing the field delimiters from semicolons to tabs to facilitate easier
# pasting of the output data into a Microsoft Excel spreadsheet.
function check_links() {

    # Run a LinkChecker command to check the links in the Talis Aspire items
    # and output any broken links to the file "broken-links.csv"

    # Declare variable
    declare -r TOTAL_LINKS="$(cat talis-aspire-links.html | wc -l)"

    # Print processing statement
    echo -e "Beginning process to get Talis Aspire broken links by checking $TOTAL_LINKS links . . .\n"

    linkchecker --no-robots --no-warnings --check-extern -o csv --user-agent "User-Agent: LinkChecker: MacEwan University Library links checking operation" talis-aspire-links.html > broken-links.csv

    # Post process the LinkChecker output file to get a valid CSV file
    
    # Remove newlines and replace with a space if the newline character is
    # preceded by a period; this removes non-end-of-record newline characters
    # in the "warningstring" field
    perl -i -p -e 's/\.\n/\. /' broken-links.csv
      
    # Remove the comment lines, and remove the second line which is the check
    # for the input file
    sed -i '/^# .*$/d' broken-links.csv ; sed -i '2d' broken-links.csv

    # Change the field/column separators from semicolons to tabs; uses the FPAT
    # variable to properly process double quotation marks around a field if
    # there is a semicolon in the field string
    gawk -v FPAT='"[^"]*"|[^;]*' -v OFS='\t' '{$1=$1} 1' broken-links.csv > broken-links-tabs.csv
    
    # Delete the "broken-links.csv" file, and then rename the file
    # "broken-links-tabs.csv" to "broken-links.csv"
    rm -f broken-links.csv && mv broken-links-tabs.csv broken-links.csv

    # Remove data processing file
    rm -f talis-aspire-links.html

    # Print processing statement
    echo -e 'Finished creating the LinkChecker broken links file "broken-links.csv"\n'

}

####
# Function to merge the metadata file and the broken links file.  Use an AWK
# command and an array to merge the associated item and list metadata from the
# "talis-aspire-metadata.csv" file with each broken link in the
# "broken-links.csv" file.  Then post process the merged file
# "talis-aspire.csv" to add the header row to the file, and rearrange the
# columns/fields so that the last six metadata fields are now the first six
# fields.
function merge_files() {

    # Print processing statement
    echo -e 'Beginning process to merge the Talis Aspire metadata file "talis-aspire-metadata.csv" and the LinkChecker broken links file "broken-links.csv" . . .\n'

    # AWK command to populate an array "a" so that each line of the metadata
    # file is indexed such that the key is the first field and the value is
    # the entire line, and then for each match on the first field of the
    # broken links file, print out the entire line of the broken links file
    # followed by the entire line of the metadata file
    #     original version of AWK command:
    #gawk -F '\t' -v OFS='\t' 'NR==FNR{a[$1]=$0;next}$1 in a{$0=$0","a[$1];print}' talis-aspire-metadata.csv broken-links.csv > talis-aspire.csv
    gawk -F '\t' -v OFS='\t' 'NR==FNR{a[$1]=$0;next} ($1) in a{print $0, a[$1]}' talis-aspire-metadata.csv broken-links.csv > talis-aspire.csv

    # Add the header row to the file
    sed -i -e '1iurlname\tparentname\tbase\tresult\twarningstring\tinfostring\tvalid\turl\tline\tcolumn\tname\tdltime\tsize\tchecktime\tcached\tlevel\tmodified\t"Web Address"\t"List Link"\t"Item Link"\tTitle\t"List Appearance"\t"Time Period"' talis-aspire.csv

    # Rearrange the columns so that the last six Talis Aspire metadata columns
    # are now the first six columns
    gawk -F '\t' -v OFS='\t' '{print $18, $19, $20, $21, $22, $23, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17}' talis-aspire.csv > talis-aspire-broken-links.csv
    
    # Remove data processing files
    rm -f broken-links.csv talis-aspire.csv talis-aspire-metadata.csv

    # Print processing statement
    echo -e '\nFinished creating a merged, tab-delimited file of Talis Aspire broken links called "talis-aspire-broken-links.csv"\n'

    # Print final processing statement
    echo 'The Talis Aspire broken links processing operation is now finished!'

}

####
# Wrapper function to control program flow and logic.  Calls each function
# sequentially to first create the needed input files, then check for broken
# links for each item's external link, and then merge the broken links output
# with the item metadata for each broken link.  None of the functions take any
# parameters or have any return values, but they all write to standard output
# which is redirected to files.
function main() {

    create_files
    check_links
    merge_files

}

main
