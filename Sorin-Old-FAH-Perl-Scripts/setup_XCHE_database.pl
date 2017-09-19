#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file creates the project and frames table on the database server
# and prepares the analysis directory locally... 
# updated for proteins in GMX core runs

use DBI;
$input = "\n     Usage\:  setup_database.pl  [projID\#]\n\n";
$name = shift(@ARGV) or die "$input";


########       define working directory & delecte old init files          ##########
$home_dir = `pwd`;
chomp($home_dir);
$home_dir =~ s/\/analysis//g;
$confname = "proj"."$name".".conf";
$infile = "$home_dir/CONFS/$confname";
print STDERR "$infile\n";
$currdir = `pwd`;
chomp $currdir;


#########      Make projectID - a basic input file           #############
open(INFILE,"$infile") or die "Can't open infile $infile\n";
while(<INFILE>) {
    @line = split;
    if ($line[0]eq'PROJECTID') { $projectID = $line[1]; }
    if ($line[0]eq'DBSERVER') { $dbserver = $line[1]; }
}
system("echo $dbserver > dbserver");
close(INFILE);

print STDERR "Read $confname:  $dbserver\n";

    
#######        MYSQL: setup at the database server          ##############
# helix metrics currently used:
#   dssp, Nhelix, Nbeta, Ncoil
#   rmsd, rg 
#   Eint, aquired

my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
$newdb = "project$projectID";
print STDERR "newdb = $newdb";

print STDERR "Creating Folding at Home Database $newdb on $dbserver\n";
$statement = $dbh->prepare("CREATE DATABASE $newdb");
$statement->execute;
$dbh->disconnect;
 
$dbh = DBI->connect("DBI:mysql:project$projectID:$dbserver",undef, undef) or print STDERR "Can't connect to project$projectID database on $dbserver\n";
$statement = $dbh->prepare("CREATE TABLE frames (run INT NOT NULL, clone INT NOT NULL, frame INT NOT NULL, rmsd FLOAT, radiusgyr FLOAT, Eint FLOAT, dssp varchar(550), Nhelix INT, Nbeta INT, Ncoil INT, acquired DATETIME)"); 
$statement->execute; print STDERR "mysql done step 1 ...\n";

$statement = $dbh->prepare("CREATE INDEX index_id ON frames (run, clone, frame)");
$statement->execute;
print STDERR "mysql done step 2 ...\n";

$statement = $dbh->prepare("CREATE INDEX index_rmsd ON frames (rmsd, run)");
$statement->execute;
print STDERR "mysql done step 3 ...\n";

$dbh->disconnect;
print STDERR "Successfully created 1 table: frames\n";
