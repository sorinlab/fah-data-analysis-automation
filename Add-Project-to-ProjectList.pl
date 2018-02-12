#!/usr/bin/perl

# This script is designed to run in the server2/analysis directory
# It inserts projects into the projectlist database on the SQL server


use DBI;

$input = "\n     Usage\:  Add-Project-to-ProjectList.pl [/path/to/proj#.xml]\n\n";
$projectXML = @ARGV[0] or die "$input";

# Begin DBI constants
## Change these values to point to the appropriate DB server
$dbserver = "134.139.52.4:3306";
$dbServerName = "'banana'";
$server = `hostname`; 
chomp $server;
$server = "'" . $server . "'";
# End DBI constants


# Open the ProjectXML to obtain the project's
# description, type, number of runs, clones, and atoms
# These values are then used for creating an entry in the table
open(INFILE, "$projectXML") or die "Can't open the file $projectXML\n";
$projType_Finder = 0;
while(my $line = <INFILE>)
{
    @split_line = split(/"/, $line);
    if(index($split_line[0], "title") !=-1)
    {
        $description = $split_line[1];
        $description = "'" . $description . "'";
    }
    if (index($split_line[0], "projtype") != -1)
    {
        $projType = $split_line[1];
	$projType = "'" . $projType . "'";
        $projType_Finder = 1;
    }
    if (index($split_line[0], "runs") != -1)
    {
        $numberOfRun = $split_line[1];
    }
    if (index($split_line[0], "clones") != -1)
    {
        $numberOfClone = $split_line[1];
    }
    if (index($split_line[0], "atoms") != -1)
    {
        $numberOfAtoms = $split_line[1];
    }
}
if($projType_Finder == 0)
{
    print("Your Project Type is not set in the project.xml\n\tEX: <projtype v='BCHE'/>\n");
    die;
}

# Use line below to test variables (Useful For Debugging)
#print($description . "\n" . $projType . "\n" . $numberOfRun . "\n" . $numberOfClone . "\n" . $numberOfAtoms . "\n"); die;

############ DO NOT MAKE CHANGES UNLESS YOU KNOW WHAT YOU ARE DOING ####################
# Connecting to the Database Server Hosted at $dbserver
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, Insert Specific Project into ProjectList
$statement = $dbh->prepare("USE ProjectList");
$statement->execute() or die "Could not use ProjectList Database: " . $statement->errstr();
$statement = $dbh->prepare("INSERT INTO ProjectList
                                (
                                    projNum,
                                    projType,
                                    dbServer,
                                    server,
                                    numRun,
                                    numClone,
                                    numAtoms,
                                    description
                                )
                                VALUES
                                    (
                                        $projectNumber,
                                        $projType,
                                        $dbServerName,
                                        $server,
                                        $numberOfRun,
                                        $numberOfClone,
                                        $numberOfAtoms,
                                        $description
                                    )"
                            );
$statement->execute() or die "Could not insert Project $projectNumber into Database: " . $statement->errstr();
print "Inserted the new Project into the Database.\n\n";
