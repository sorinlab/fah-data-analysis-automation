#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file creates the project and frames table on the database server
# and prepares the analysis directory locally... 
# updated for proteins in GMX core runs

# Getting user's argument here
use DBI;
$input = "\n     Usage\:  setup_database.pl  Project-Name\n\n";
$name = shift(@ARGV) or die "$input";

# 
