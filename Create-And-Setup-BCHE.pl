#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file creates the Database and Table on the database server
# and prepares the analysis directory locally... 
# updated for proteins in GMX core runs

# Getting user's argument here
use DBI;
$input = "\n     Usage\:  Create-And-Setup-BCHE.pl \n\n";


# Connecting to the Database Server Hosted by Banana
$dbserver = "134.139.52.4:3306";
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, create a new database with the Project_Name
$statement = $dbh->prepare("CREATE DATABASE BCHE");
$statement->execute();
print "New Database created with the name BCHE\n";

# Now create a new Table with the Project_Name inside this new Database
$statement = $dbh->prepare("USE BCHE");
$statement->execute();
$statement = $dbh->prepare("CREATE TABLE BCHE
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
$statement->execute();
print "New Table created with the name $name \n";