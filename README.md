### *** system-links-checking repository ***

*MRB: Sat 28-Dec-2024*

Purpose: This repository contains shell scripts that are used to check
information systems for broken links.

Description: This repository contains five Bash shell scripts that are used
to identify broken links on five different MacEwan University Library
information systems: the Drupal-based Library website; the DSpace institutional
repository (RO@M); the LibGuides guide management system; the Omeka digital
exhibits platform; and the Talis Aspire course resource list management system.
Each Bash shell script contains informative notes in the form of comments at
the beginning of the script, with information about the program flow of the
script, as well as detailing the output files that are created.

The drupal-broken-links.sh, libguides-broken-links.sh, and
omeka-broken-links.sh scripts are all relatively straightforward, in that they
consist of just a single system call to the LinkChecker application (see
(https://linkchecker.github.io/linkchecker/) in the form of a LinkChecker
command, and then some post processing of the LinkChecker output file.
However, the libguides-broken-links.sh script does contain some additional post
processing of the LinkChecker output file, using a helper mappings file called
libguides-mappings.tsv to add another field consisting of guide names to the
output file, and the script features two functions to control program flow and
logic.

The drupal-broken-links.sh and talis-aspire-broken-links.sh scripts are more
complex, with each script featuring three functions that serve to
compartmentalize and control program flow and logic.  These two scripts are
more involved because neither the DSpace institutional repository nor the Talis
Aspire course resource list management system is crawlable by a web crawler,
robot, or spider.

The central problem to be solved with the DSpace script is obtaining each
item's URL (as opposed to Handle.Net URI or DSpace URI), and the central
problem to be solved with the Talis Aspire script is obtaining the list URL
and item URL that a particular broken link is located in.  Both scripts
successfully address each of these problem spaces.

The files in this repository are the following:

* drupal-broken-links.sh
    - The Bash shell script to check for broken links on the Library's
      Drupal web content management system.
* dspace-broken-links.sh
    - The Bash shell script to check for broken links on the Library's
      DSpace institutional repository.
* libguides-broken-links.sh
    - The Bash shell script to check for broken links on the Library's
      LibGuides guide management and curation platform.
* libguides-mappings.tsv
    - A tab-separated helper file for the libguides-broken-links.sh script that
      contains the LibGuides mappings in three fields for the guide base page
      real URL, the guide base page alias URL, and the guide name.
* omeka-broken-links.sh
    - The Bash shell script to check for broken links on the Library's
      Omeka digital exhibits platform.
* README.md
    - This readme file that contains information about the files in this
      repository.
* talis-aspire-broken-links.sh
    - The Bash shell script to check for broken links on the Library's
      Talis Aspire course resource list management system.

The current version of the Python 3-based LinkChecker application that is being
used to check information system links is 10.5.0, released on 3 September 2024.
