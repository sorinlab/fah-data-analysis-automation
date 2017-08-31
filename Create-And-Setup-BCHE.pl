#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file creates the Database and Table on the database server
# and prepares the analysis directory locally... 
# updated for proteins in GMX core runs

# Getting user's argument here
use DBI;
$input = "\n     Usage\:  Create-And-Setup-BCHE.pl  Project_Name\n\n";
$name = shift(@ARGV) or die "$input";

# CREATE TABLE BCHE(    proj INT NOT NULL,    run INT NOT NULL,    clone INT NOT NULL,    frame INT NOT NULL,    rmsd_pro FLOAT,    rmsd_complex FLOAT,    COMdist FLOAT,    rg_pro FLOAT,    E_vdw FLOAT,    E_qq FLOAT,    dssp VARCHAR(550),     Nhelix INT,     Nbeta INT,     Ncoil INT,     acquired DATETIME,    dateacquried DATE,    timeacquired TIME,    PRIMARY KEY (proj, run, clone, frame));

# Connecting to the Database Server Hosted by Banana
$dbserver = "localhost";
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, create a new database with the Project_Name
$statement = $dbh->prepare("CREATE DATABASE $name");
$statement->execute;
print "New Database created with the name $name";

# Now create a new Table with the Project_Name
$statement = $dbh->prepare("CREATE TABLE BCHE( proj INT NOT NULL, run INT NOT NULL, clone INT NOT NULL, frame INT NOT NULL, rmsd_pro FLOAT, rmsd_complex FLOAT, COMdist FLOAT, rg_pro FLOAT, E_vdw FLOAT, E_qq FLOAT, dssp VARCHAR(550), Nhelix INT, Nbeta INT, Ncoil INT, dateacquried DATE, timeacquired TIME, PRIMARY KEY (proj, run, clone, frame)");
$statement = $dbh->execute;
print "New Table created with the name $name";