#!/usr/bin/perl
use DBI;

$input = "\n     Usage\:  add_proj_to_lists.pl  [projID\#]  [debug? Y\|N]\n\n";
$name = @ARGV[0] or die "$input";
$debug = @ARGV[1] or die "$input";
if($debug eq 'Y'){ $debug = 1; } else { $debug = 0; }

$home_dir = `pwd`;
chomp($home_dir);
$home_dir =~ s/\/analysis//g;
$confname = "proj"."$name".".conf";
$infile = "$home_dir/CONFS/$confname";

open(INFILE,"$infile") or die "Can't open infile $infile\n";
while(<INFILE>) {
  @line = split;
  if ($line[0] eq 'PROJECTID') { $projectID = $line[1]; }
  if ($line[0] eq 'DBSERVER') { $dbserver = $line[1]; }
  if ($line[0] eq 'NUM_RUN_TYPES') { $numruntypes = $line[1]; }
  if ($line[0] eq 'TEMPERATURE') { $temperature = $line[1]; }
  if ($line[0] eq 'NUM_RUNS') { $numruns = $line[1]; }
  if ($line[0] eq 'NUM_CLONES') { $numclones = $line[1]; }
  if ($line[0] eq 'MAX_ITER') { $maxiter = $line[1]; }
  if ($line[0] eq 'RETRY_MAX') { $retrymax = $line[1]; }
  if ($line[0] eq 'MAX_GENS') { $maxgens = $line[1]; }
  if ($line[0] eq 'DESCRIPTION') { $description = $line[1]; }
  if ($line[0] eq 'STATSCREDIT') { $statscredit = $line[1]; }
  if ($line[0] eq 'PROJECT_TYPE') { $ptype = $line[1];   }
  if ($line[0] eq 'NATOM') { $numatoms = $line[1]; }
  if ($line[0] eq 'DB_TEMPORAL_RESOLUTION') { $tempresps = $line[1]; }
  if ($line[0] eq 'DB_NUM_FRAMES') { $framesperWU = $line[1]; }
}
close(INFILE);
if($numruntypes==0) { $numruntypes=1; }
$server = `echo \$HOSTNAME`;
chomp $server;


###### MYSQL for projectlist ##########
print STDERR "\n\nAdding a record to the projectlist database for this project using the information in $infile\n\n";
$string = "UPDATE projects SET dbserver = '$dbserver',numruntypes = '$numruntypes',temperature = '$temperature',numruns = '$numruns',numclones = '$numclones',maxiter = '$maxiter',retrymax = '$retrymax',maxgens = '$maxgens',description = '$description',statscredit = '$statscredit',projecttype = '$ptype',numatoms = '$numatoms',server = '$server',tempresps = '$tempresps',framesperWU = '$framesperWU' WHERE ( projectID = '$projectID' )";
print STDERR "$string\n\n";

if($debug==0){
	print STDOUT "Connecting mysql server on $dbserver\n\n";
	$dbh = DBI->connect("DBI:mysql:projectlist:$dbserver",server,"") or print STDERR "Can't connect to projectlist database on $dbserver\n";

	# check for previous listings of this project #
	$statement = $dbh->prepare("SELECT * FROM projects WHERE (projectID = '$projectID')");
        $statement->execute;
        $existingrows = $statement->rows;

	if($existingrows){
        	print STDOUT "SKIPPING INSERT - JUST UPDATING project info for $projectID\n\n";
        }else{
		# insert an index value for the projectID #
		$statement = $dbh->prepare("INSERT INTO projects (projectID) VALUES ('$projectID')");
        	$statement->execute;
	}

	$statement = $dbh->prepare("$string");
	$statement->execute;
	$statement->finish;
	$dbh->disconnect;
	print "DONE ............. \n\n";
}
