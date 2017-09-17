#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file creates the Database and Table on the database server

use DBI;
$input = "\n     Usage\:  Create-And-Setup-BCHE.pl \n\n";

# Name of the Database/Table here
$name = "BCHE";

# Connecting to the Database Server Hosted by Banana
$dbserver = "134.139.52.4:3306";
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, create a new database with the Project_Name
$statement = $dbh->prepare("CREATE DATABASE $name");
$statement->execute() or die "Could not create $name Database: " . $statement->errstr();
print "New Database created with the name $name\n";

# Now create a new Table with the Project_Name inside this new Database
$statement = $dbh->prepare("USE $name");
$statement->execute() or die "Could not use Database $name: " . $statement->errstr();
$statement = $dbh->prepare("CREATE TABLE $name
                            ( 
                              proj INT NOT NULL, 
                              run INT NOT NULL, 
                              clone INT NOT NULL, 
                              frame INT NOT NULL, 
                              rmsd_pro FLOAT, 
                              rmsd_complex FLOAT, 
                              COMdist FLOAT, 
                              rg_pro FLOAT, 
                              E_vdw FLOAT, 
                              E_qq FLOAT, 
                              dssp VARCHAR(550), 
                              Nhelix INT, 
                              Nbeta INT, 
                              Ncoil INT, 
                              dateacquried DATE, 
                              timeacquired TIME, 
                              PRIMARY KEY (proj, run, clone, frame)
                            )"
                          );
$statement->execute() or die "Could not create $name table: " . $statement->errstr();
print "New Table created with the name $name \n\n";