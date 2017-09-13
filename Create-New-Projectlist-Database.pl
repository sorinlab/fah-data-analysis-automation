#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file creates the projectlist database on the sql server


use DBI;
$input = "\n     Usage\:  Create-New-Projectlist-Database.pl \n\n";


# Connecting to the Database Server Hosted by Banana
$dbserver = "134.139.52.4:3306";
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, create a new ProjectList Database
$statement = $dbh->prepare("CREATE DATABASE ProjectList");
$statement->execute;
print "New ProjectList Database created";

# Now create a new Projectlist Table under the Projectlist Database
$statement = $dbh->prepare("USE ProjectList");
$statement = $dbh->execute;
$statement = $dbh->prepare("CREATE TABLE ProjectList
                            (  
                              projNum INT NOT NULL,
                              codeName VARCHAR(10) NOT NULL,
                              dbServer VARCHAR(100) NOT NULL,
                              server VARCHAR(50) NOT NULL,
                              temperature DOUBLE(3,2),
                              numRun INT,
                              numClone INT,
                              numAtoms INT,
                              description VARCHAR(500),
                              PRIMARY KEY (projNum)
                            )"
                          );
$statement = $dbh->execute;
print "New ProjectList table created.";
                            