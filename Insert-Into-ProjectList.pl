#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file inserts projects into the projectlist database on the sql server


use DBI;
$input = "\n     Usage\:  Insert-Into-ProjectList.pl \n\n";

########## Please Update the following variables to suit your Project #########
$projectNumber = 8020;
$codeName = "BCHE";
$databaseServer = "ProjectList";
$server = "Folding1";
$temperature = 100.00;
$numberOfRun = 100;
$numberOfClone = 100;
$numberOfAtoms = 100;
$description = "This is the Project 8020 of BCHE.";
########### END of Variables to suit your Project ##############################


############ DO NOT MAKE CHANGES UNLESS YOU KNOW WHAT TO DO ####################
# Connecting to the Database Server Hosted by Banana
$dbserver = "134.139.52.4:3306";
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, Insert Specific Project into the ProjectList
$statement = $dbh->prepare("USE ProjectList");
$statement->execute();
$statement = $dbh->prepare("INSERT INTO ProjectList
                                (
                                    projNum,
                                    codeName,
                                    dbServer,
                                    server,
                                    temperature,
                                    numRun,
                                    numClone,
                                    numAtoms,
                                    description
                                )
                                VALUES
                                    (
                                        $projectNumber,
                                        $codeName,
                                        $databaseServer,
                                        $server,
                                        $temperature,
                                        $numberOfRun,
                                        $numberOfClone,
                                        $numberOfAtoms,
                                        $description
                                    ))"
                            );
$statement->execute();
print "Inserted the new Project into the Database.\n\n";