#!/usr/bin/perl
# This version is designed to run in the server2/analysis subdirectory
# This file inserts projects into the projectlist database on the sql server


use DBI;

$input = "\n     Usage\:  Insert-Into-ProjectList.pl [projectNumber]\n\tMake sure the server config.xml is in the same directory as this Script.\n";
$projectNumber = @ARGV[0] or die "$input";

$projectXML = $projectNumber . ".xml";

$projectNumber = substr $projectNumber, 4;

$databaseServer = "'banana'";
$server = "'Folding1'";

$home_dir = "/home/server/server2";
chomp($home_dir);
$config_xml = "$home_dir/config.xml";

# Opening the server xml inorder to find the full path to the projectXML
open(INFILE, "$config_xml") or die "Can't open the file $config_xml\n";
$projectFinder = 0;
while(<INFILE>)
{
    @line = split;
    if(index($line[1], $projectXML) != -1)
    {
        $projectFinder = 1;
        $projectXML = substr $line[1], 6, -3;
        print("Project's Full Path Found: " . $projectXML . "\n");
        last; # Using "last" to exit out of the while loop
    }
}
if($projectFinder == 0)
{
    print("Sory Project XML: " . $projectXML . " is not found \n");
    die;
}
close(INFILE);

# If full path is found, open the ProjectXML to set the variables
open(INFILE, "$home_dir/$projectXML") or die "Can't open the file $projectXML\n";
$projType_Finder = 0;
while(<INFILE>)
{
    @line = @split(/"/, $line);
    if (index($line[0], "title") != -1)
    {
        $description = $line[2];
	    $description = "'" . $description . "'";
    }
    if (index($line[0], "projtype") != -1)
    {
        $projType = $line[2];
	    $projType = "'" . $projType . "'";
        $projType_Finder = 1;
    }
    if (index($line[0], "run") != -1) {$numberOfRun = $line[2]}
    if (index($line[0], "clones") != -1) {$numberOfClone = $line[2]}
    if (index($line[0], "atoms") != -1) {$numberOfAtoms = $line[2]}
}
if($projType_Finder == 0)
{
    print("Your Project Type is not set in the project.xml\n\tEX: <projtype v='BCHE'/>\n");
    die;
}

# Use below line to test variables output (For Debugging)
#print($description . "\n" . $projType . "\n" . $numberOfRun . "\n" . $numberOfClone . "\n" . $numberOfAtoms . "\n");



############ DO NOT MAKE CHANGES UNLESS YOU KNOW WHAT TO DO ####################
# Connecting to the Database Server Hosted by Banana
$dbserver = "134.139.52.4:3306";
my $dbh = DBI->connect("DBI:mysql:mysql:$dbserver",server,"") or print STDERR "Can't connect to mysql database on $dbserver\nTry giving this server permissions\n";
print "Database connection established\n";

# Once Connected, Insert Specific Project into the ProjectList
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
                                        $databaseServer,
                                        $server,
                                        $numberOfRun,
                                        $numberOfClone,
                                        $numberOfAtoms,
                                        $description
                                    )"
                            );
$statement->execute() or die "Could not insert Project $projectNumber into Database: " . $statement->errstr();
print "Inserted the new Project into the Database.\n\n";
