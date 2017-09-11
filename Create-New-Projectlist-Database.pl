#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file creates the projectlist database on the sql server


use DBI;
$input = "\n     Usage\:  Create-New-Projectlist-Database.pl \n\n";


# Connecting to the Database Server Hosted by Banana
$dbserver = "localhost";
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, create a new ProjectList Database
$statement = $dbh->prepare("CREATE DATABASE ProjectList");
$statement->execute;
print "New ProjectList Database created";