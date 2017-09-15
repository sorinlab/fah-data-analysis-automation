#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file inserts projects into the projectlist database on the sql server


use DBI;
$input = "\n     Usage\:  Insert-Into-ProjectList.pl [projectNumber]\n\n";
$projectNumber = @ARGV[0] or die "$input";

$home_dir = `pwd`;
chomp($home_dir);
$config_Dir = "$home_dir/config.xml";
$config_xml = $projectNumber.".xml";

open(INFILE, "$config_xml") or die "Can't open the file $config_xml\n";
while(<INFILE>)
{
    @line = split;
    print($line[0]."\n");
}



# ############ DO NOT MAKE CHANGES UNLESS YOU KNOW WHAT TO DO ####################
# # Connecting to the Database Server Hosted by Banana
# $dbserver = "134.139.52.4:3306";
# my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
# print "Database connection established\n";

# # Once Connected, Insert Specific Project into the ProjectList
# $statement = $dbh->prepare("USE ProjectList");
# $statement->execute() or die "Could not use ProjectList Database: " . $statement->errstr();
# $statement = $dbh->prepare("INSERT INTO ProjectList
#                                 (
#                                     projNum,
#                                     codeName,
#                                     dbServer,
#                                     server,
#                                     temperature,
#                                     numRun,
#                                     numClone,
#                                     numAtoms,
#                                     description
#                                 )
#                                 VALUES
#                                     (
#                                         $projectNumber,
#                                         $codeName,
#                                         $databaseServer,
#                                         $server,
#                                         $temperature,
#                                         $numberOfRun,
#                                         $numberOfClone,
#                                         $numberOfAtoms,
#                                         $description
#                                     )"
#                             );
# $statement->execute() or die "Could not insert Project $projectNumber into Database: " . $statement->errstr();
# print "Inserted the new Project into the Database.\n\n";