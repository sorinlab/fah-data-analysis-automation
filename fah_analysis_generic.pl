#!/usr/bin/perl
use DBI;

# Perl trim function to remove whitespace from the start and end of the string
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+|\s+$//g;
	return $string;
}

#######################	setup I/O ############################
# Dirs #
my $home_dir = "/home/xavier";
my $analysis_dir = "$home_dir/fah-analysis-testing";
my $fah_files = "$analysis_dir/fah-files";
my $sandbox_dir = "$analysis_dir/sandbox";
# Files #
my $log = "$analysis_dir/analyzer-logs/analyzer.log";
my $queue = "$analysis_dir/queue.txt";
my $work_finished = "$analysis_dir/done.txt";
my $lock = "$analysis_dir/lock.txt";

#######################	Open Logger ############################
# This script always writes to a log file
# Status updates, warnings and errors will appear in this file
open my $LOG, ">", $log || die "\nError: can't open analyzer.log\n\n";

#######################	Set Lock ############################
if (-e $lock) {
	print $LOG "[WARNING] Lock set. Exiting...\n";
	close($LOG);
	die;
} else {
	print $LOG "Analyzer starting...\n";
	my $sys_call_error = system("touch $lock"); 
	if($sys_call_error) {
		print $LOG "[ERROR] Unable to set lock=$lock. Check for errors in the configuration. Exiting...\n";
		close($LOG);
		die;
	}
}

################ Sanity check: queue & work_finished  ######################
if (-e $queue) {
	print $LOG "Opening $queue...\n";
	unless(open $QUEUE, "<", $queue) {
		print $LOG "[ERROR] Unable to open queue=$queue. Unsetting lock and exiting...\n";
		system("rm $lock");
		die;
	}
	chomp(@queue_lines = <$QUEUE>);
	close($QUEUE);
	my $num_queue_items = scalar @queue_lines;
	print $LOG "$num_queue_items work units to be analyzed...\n";
} else {
	print $LOG "[ERROR] queue=$queue does not exist. Check for erros in the configuration. Unsetting lock and exiting...\n";
	close($LOG);
	system("rm $lock");
	die;
}
if (-e $work_finished) {
	print $LOG "work_finished=$work_finished exists.\n";
} else {
	print $LOG "[ERROR] work_finished=$work_finished does not exist. Check for erros in the configuration. Unsetting lock and exiting...\n";
	close($LOG);
	system("rm $lock");
	die;
}
print $LOG "Sanity check: queue & work_finished passed. Continuing...\n";

#################### get frame info #########################
foreach (@queue_lines) { 
	my @queue_data = split(/\t/, $_);
	my $project_name = trim($queue_data[0]);
	my $work_unit = trim($queue_data[1]);
	
	#################### .xtc check ###################
	if (-e $work_unit) {
		@work_unit_information = split(/\//, $work_unit);
		foreach(@work_unit_information) {
			if (index($_, "frame") != -1) {
				$xtc_base_dir = substr($work_unit, 0, -(length($_) + 1));
				@xtc_split = split(/\./, $_); 
				$f = substr($xtc_split[0], 5);
			} elsif(index($_, "PROJ") != -1) {
				$pro = substr($_, 4);
			}
		}

		#################### DATETIME ########################
		$wu_time_info = `ls -l --full-time $work_unit | awk '{print \$6" "\$7}'`;
		chomp $wu_time_info;
		for($wu_time_info) {  s/\.000000000//g; }
		@datenew = split(/\./,$wu_time_info);
		$timeaq = "@datenew[0]";
		@timeaq_split =  split(/\ /,$timeaq);
		$date = $timeaq_split[0];
		$time = $timeaq_split[1];

		############### get/prep the gromacs files for analysis  ##############
		$edr = "$xtc_base_dir/frame$f.edr";
		$tpr = "$xtc_base_dir/frame0.tpr";

		print $LOG "Processing xtc=$work_unit\n";
		print $LOG "Processing edr=$edr\n";
		print $LOG "Processing tpr=$tpr\n";

		if((-e $edr) && (-e $tpr)) {

			# define (input) filenames #
			$xtcfile = "$sandbox_dir/current_frame.xtc";
			$edrfile = "$sandbox_dir/current_frame.edr"; 
			$tprfile = "$sandbox_dir/current_frame.tpr";
			$ndxfile = "$fah_files/proj$pro.ndx";
			
			# Copy raw data to sandbox
			system("cp $work_unit $xtcfile");
			system("cp $edr $edrfile");
			system("cp $tpr $tprfile");

			# define (output) filenames #
			$rmsdfile = "$sandbox_dir/rmsd.xvg";
			$rmsdcomplexfile = "$sandbox_dir/rmsd_complex.xvg";
			$gyratefile = "$sandbox_dir/gyrate.xvg";
			$dsspfile = "$sandbox_dir/ss.xpm";
			$dsspcountsfile = "$sandbox_dir/scount.xvg";
			$mindistfile = "$sandbox_dir/mindist.xvg";
			$energyfile = "$sandbox_dir/energy.xvg";

			
			# generate gromacs data files #
			# for sans inhibitor / PROJ8200 #
			if($pro eq "8200") {
				system("echo 1 1 | g_rms -s $tprfile -f $xtcfile -n $ndxfile -o $rmsdcomplexfile"); 
				system("echo 1 1 | g_rms -s $tprfile -f $xtcfile -n $ndxfile -o $rmsdfile");
			} else {
				system("echo 1 24 | g_rms -s $tprfile -f $xtcfile -n $ndxfile -o $rmsdcomplexfile"); # for complexes
				system("echo 1 1 | g_rms -s $tprfile -f $xtcfile -n $ndxfile -o $rmsdfile"); # for rmsd of protein only
			}
			system("echo 1 | g_gyrate -s $tprfile -f $xtcfile -o $gyratefile");
			system("echo 1 | do_dssp -f $xtcfile -s $tprfile -n $ndxfile -o $dsspfile -sc $dsspcountsfile"); # good for all projects			
			system("echo 1 20 | g_mindist -s $tprfile -f $xtcfile -n $ndxfile -od $mindistfile"); # set this value to 0.0 for PROJ8200 with no inhibitor present
			# for vdW and QQ energies #
			# Set this value to 0.0 for PROJ8200 with no inhibitor present #
			# 48 and 49 should be named similar to LJ-SR:Protein-DP2 and Coul-SR:Protein-DP2 #
			system("echo 48 49 | g_energy -s $tprfile -f $edrfile -o $energyfile");

			`rm $lock`;
			close $LOG;
			die;

			# get rmsd's from relaxed structure using g_rms #
			# unless(open my $RMS,"<", $rmsdfile) {
			# 	print LOGFILE "[ERROR] When attempting to open $rmsdfile for xtc=$work_unit. Unsetting lock and exiting...\n";
			# 	close($LOG);
			# 	system("rm $lock");
			# 	die;
			# }
			# $iter=0;
			# while($line=<$RMS>){
			# 	chomp $line;
			# 	for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
			# 	@lined = split(/ /,$line);
			# 	if(@lined[0] =~ /\d+/) {
			# 		if($iter>0){
			# 		# to check for extra t_zero line #
			# 			if($lined[0] == $oldline) { 
			# 			$oldline = $lined[0]; 
			# 			next;
			# 		}
			# 		}
			# 		$oldline = $lined[0]; 
			# 	$tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu); # in sequential frame # ... ie. [201..399] for frame1.xxx
			# 	$rms1{$tim} = @lined[1] * $nm2A;
			# 	$iter++;
			# 	}
			# }
			# close($RMS);

			# # get chain Rg using g_gyrate # 
			# unless(open(RG,"<", $gyratefile)) {
			# 	print LOGFILE "[ERROR] When attempting to open $gyratefile for xtc=$work_unit. Unsetting lock and exiting...\n";
			# 	close($LOG);
			# 	system("rm $lock");
			# 	die;
			# }
			# $iter=0;
			# while($line=<RG>){
			# 	chomp $line;
			# 	for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
			# 	@lined = split(/ /,$line);
			# 	if(@lined[0] =~ /\d+/) {
			# 		if($iter>0){
			# 			# to check for extra t_zero line #
			# 			if($lined[0] == $oldline) {
			# 				$oldline = $lined[0];
			# 				next;
			# 			}
			# 		}
			# 		$oldline = $lined[0];
			# 		$tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu);
			# 		$radgyr{$tim} = @lined[1] * $nm2A;
			# 		$iter++;
			# 	}
			# }
			# close(RG);

			# get Eint .edr files #
			# unless(open(EDR,"<", "?")) {
			# 	print LOGFILE "[ERROR] When attempting to open ? for xtc=$work_unit. Unsetting lock and exiting...\n";
			# 	close($LOG);
			# 	system("rm $lock");
			# 	die;
			# } 
			# $iter=0;
			# while($line=<EDR>){
			# 	chomp $line;
			# 	for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
			# 	@lined = split(/ /,$line);
			# 	if((@lined[1] =~ /\d+/)&&(@lined[0] ne "\@")) {
			# 		if($iter>0){
			# 			# to check for extra t_zero line #
			# 			if($lined[1] == $oldline) {
			# 				$oldline = $lined[1];
			# 				next;
			# 			}
			# 		}
			# 			$oldline = $lined[0];
			# 		# need in sequential frame # ... ie. [11..19] for frame1.xxx
			# 		$tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu); 
			# 		$Epot{$tim} = @lined[1] - @lined[2] - @lined[3] - @lined[4] - @lined[5];
			# 		$iter++;
			# 	}
			# }
			# close(EDR);

			# get dssp data #
			# $iter=0;
			# $sstmp = "$sandbox_dir/ss.tmp";
			# `tail -522 $dsspfile > $sstmp`; # 522 signifies # of residues DSSP is analyzing
			# for($ii = 0; $ii <= $framesperwu; $ii++) {
			# 	$Nhelix{$ii} = 0;
			# 	$Nalpha{$ii} = 0;
			# 	$Nbeta{$ii} = 0;
			# 	$Npi{$ii} = 0;
			# 	$Ncoil{$ii} = 0;
			# }
			# unless(open(DSSP,"<", $sstmp)) {
			# 	print LOGFILE "[ERROR] When attempting to open $sstmp for xtc=$work_unit. Unsetting lock and exiting...\n";
			# 	close($LOG);
			# 	system("rm $lock");
			# 	die;
			# }
			# while($line=<DSSP>){
			# 	chomp $line;
			# 	for($line) { s/\"//; s/\,//;  s/\"//; }
			# 	@newline = split(//,$line);
			# 	for($ii = 0; $ii < $framesperwu; $ii++) { 
			# 		# each dssp letter is specified as $dssp{res,time} #
			# 		$dssp{$iter,$ii} = $newline[$ii];
			# 	}
			# 	$iter++;	
			# }
			# $resiter = $iter;
			
			# for($ii = 0; $ii < $framesperwu; $ii++) { 
			# 	for($iter = 0; $iter < $resiter; $iter++) { 
			# 		if($dssp{$iter,$ii} eq "H"){ $Nhelix{$ii}++; }
			# 		if($dssp{$iter,$ii} eq "G"){ $Nhelix{$ii}++; }
			# 		if($dssp{$iter,$ii} eq "I"){ $Nhelix{$ii}++; }
			# 		if(($dssp{$iter,$ii} eq "B")||($dssp{$iter,$ii} eq "E")){ $Nbeta{$ii}++; }
			# 		if(($dssp{$iter,$ii} eq "~")||($dssp{$iter,$ii} eq "S")||($dssp{$iter,$ii} eq "T")){ $Ncoil{$ii}++; }
			# 	}
			# }

			# for($ii = 0; $ii < $framesperwu; $ii++) { 
			# 	@dssp_str = '';
			# 	for($iter = 0; $iter < $resiter; $iter++) { 
			# 		push @dssp_str,$dssp{$iter,$ii};
			# 	}	
			# 	$dssp_out{$ii} = "@dssp_str";
			# 	for($dssp_out{$ii}){ s/ //g; }
			# }

			# # adjust the time ;>) #
			# for($iter=0; $iter<$itermax; $iter++){
			# 	$framenew[$iter] = $f * $def_framesperwu + $iter;	 
			# 	$tim = $framenew[$iter];
			# 	$dssp_out2{$tim} = $dssp_out{$iter};
			# 	$Nhelix2{$tim} = $Nhelix{$iter};
			# 	$Nbeta2{$tim}  = $Nbeta{$iter};
			# 	$Ncoil2{$tim}  = $Ncoil{$iter}; # to disclude terminal residues!!!
			# }
			# if(!($debug)){ system("rm *.xvg current_frame.* *.trr *.edr dd* *2.xtc md.log mdout.mdp energy.tpr \\#* ss.xpm ss.tmp gromp*"); }
		}
	} else {
		print $LOG "[ERROR] MISSING XTC=$work_unit. Unsetting lock and exiting...\n";
		close($LOG);
		system("rm $lock"); 
	}
}

############## MYSQL stuff: report values to logfile DB ###################
	
# 	print LOGFILE "$window $clientname $clientip ... ";

# 		if(!($debug)){
# 		$dbh = DBI->connect("DBI:mysql:project$pro:$dbserver",server,"") or print LOGFILE "Can't connect to FAH database on $dbserver ... ";
# 	}	 
# 	for($iter=0;$iter<$itermax;$iter++){	     
# 		$frame = $framenew[$iter];
# 		if(!($debug)){
# 		$statement = $dbh->prepare("SELECT * FROM frames WHERE (run = '$r' AND clone = '$c' AND frame = '$frame')");
# 		$statement->execute;
# 		$existingrows = $statement->rows;

# 		if ($existingrows) { 
# 			if($iter == 0){ print LOGFILE "SKIPPING INSERT - JUST UPDATE ... "; }
# 		} else { 
# 			$statement = $dbh->prepare("INSERT INTO frames (run, clone, frame) VALUES ('$r','$c','$frame')");	
# 			$statement->execute;
# 		}
# 		}
# 		$query = "UPDATE frames SET rmsd = '$rms1{$frame}', Eint = '$Eint{$frame}', radiusgyr = '$radgyr{$frame}', dssp = '$dssp_out2{$frame}', Nhelix = '$Nhelix2{$frame}', Nbeta = '$Nbeta2{$frame}', Ncoil = '$Ncoil2{$frame}', acquired = '$timeaq'";
# 		$query .= " WHERE ( run = '$r' AND clone = '$c' AND frame = '$frame' )"; 
# 		print $LOG "Query $query\n\n";
# 		if(!($debug)){
# 		$statement = $dbh->prepare("$query");
# 		$statement->execute;
# 		$statement->finish;
# 		}
# 	}
# 	print LOGFILE "\n";
# 		if(!($debug)){ $dbh->disconnect; }

# #print STDERR "Finishing input_records.prl $infile\n";
# system("touch $analysis_dir/job_finished");
# system("/bin/rm $analysis_dir/running_flag");
# close(INFILE);
# close(LOGFILE);
# close($LOG);
# if(!($debug)){ system("mv $logfile DONE/; mv $infile LOGS/; rm debug.log"); }
