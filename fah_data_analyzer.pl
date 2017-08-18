#!/usr/bin/perl
use DBI; 
$updated = "08-17-17"; 

# Perl trim function to remove whitespace from the start and end of the string
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+|\s+$//g;
	return $string;
}

#######################	setup I/O ############################
# Dirs #
$home_dir = "...";
$analysis_dir = "$home_dir/fah-data-analysis-automation";								
$bin_dir = "$analysis_dir/bin";
$gro_dir = "$analysis_dir/gro-files";
$conf_dir = "$analysis_dir/project-conf";
$sandbox_dir = "$analysis_dir/sandbox";
# Files #
$log = "$analysis_dir/analyzer-logs/analyzer.log";
$queue = "$analysis_dir/queue_sorted.txt";
$work_finished = "$analysis_dir/done.txt";
$lock = "$analysis_dir/lock.txt";

#######################	DB Configuration ############################
$db="MYTEST";
$host="localhost";
$user="root";
$password="rootpass";

######### defaults stuff ###########
$def_frame_size = 100; # time between frames in ps #
$def_framesperwu = 10; 
$def_md_timestep = 2.0; # in fs
$nm2A = 10.0; # nm to Angstrom conversion

#######################	Open Logger ############################
# This script always writes to a log file
# Status updates, warnings and errors will appear in this file
$debug = 0;
open(LOG, ">", $log) || die "\nError: can't open analyzer.log\n\n";

#######################	Set Lock ############################
if (-e $lock) {
	print LOG "[WARNING] Lock set. Exiting...\n";
	close(LOG);
	die;
} else {
	print LOG "Analyzer starting...\n";
	$sys_call_error = system("touch $lock"); 
	if($sys_call_error) {
		print LOG "[ERROR] Unable to set lock=$lock. Check for errors in the configuration. Exiting...\n";
		close(LOG);
		die;
	}
}

################ Sanity check: queue & work_finished  ######################
if (-e $queue) {
	print LOG "Opening $queue...\n";
	unless(open(QUEUE, "<", $queue)) {
		print LOG "[ERROR] Unable to open queue=$queue. Unsetting lock and exiting...\n";
		system("rm $lock");
		die;
	}
	chomp(@queue_lines = <QUEUE>);
	close(QUEUE);
	$num_queue_items = scalar @queue_lines;
	print LOG "$num_queue_items work units to be analyzed...\n";
} else {
	print LOG "[ERROR] queue=$queue does not exist. Check for erros in the configuration. Unsetting lock and exiting...\n";
	close(LOG);
	system("rm $lock");
	die;
}
if (-e $work_finished) {
	print LOG "work_finished=$work_finished exists.\n";
} else {
	print LOG "[ERROR] work_finished=$work_finished does not exist. Check for erros in the configuration. Unsetting lock and exiting...\n";
	close(LOG);
	system("rm $lock");
	die;
}
print LOG "Sanity check: queue & work_finished passed. Continuing...\n";

#################### get frame info #########################

# To-do implement shift for processing 'n' WUs instead of all (command line option)
foreach (@queue_lines) { 
	my @queue_data = split(/\t/, $_);
	$project_name = trim($queue_data[0]);
	$work_unit = trim($queue_data[1]);
	
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

		#################### Obtain proj conf information ###################
		$conf_file_path = "$conf_dir/proj$pro.conf"; 
		if (-e $conf_file_path) {
			print LOG "Opening $conf_file_path...\n";
			unless(open(CONF, "<", $conf_file_path)) {
				print LOG "[ERROR] Can't get vital info from .conf file. Unsetting lock and exiting...\n";
				close(LOG);
				system("rm $lock");
				die;
			}
			chomp(@proj_conf_lines = <CONF>);
			close(CONF);
			foreach (@proj_conf_lines) {
				$line = trim($_);
				@linein = split(/ /, $line);
				if($linein[0] eq 'MD_TIMESTEP'){ $md_timestep = $linein[1]; }
				elsif($linein[0] eq 'DB_NUM_FRAMES'){ $framesperwu = $linein[1]; }
				elsif($linein[0] eq 'DB_TEMPORAL_RESOLUTION'){ $frame_size = $linein[1]; }
			}
		} else {
			print LOG "[ERROR] conf_file_path=$conf_file_path does not exist. Check for errors in the configuration and queue(mislabeled proj #s). Unsetting lock and exiting...\n";
			close(LOG);
			system("rm $lock");
			die;
		}

		#################### DATETIME (UNCOMMENT) ########################
		$date = `ls -l --full-time $work_unit | awk '{print \$6" "\$7}'`;
		chomp $date;
		for($date) {  s/\.000000000//g; }
		@datenew = split(/\./,$date);
		$timeaq = "@datenew[0]";

		############### get/prep the gromacs files for analysis  ##############
		if($md_timestep==0) {
			$md_timestep = $def_md_timestep;
		} else {
			$def_md_timestep = $md_timestep;
		}
		if($framesperwu==0) {
			$framesperwu = $def_framesperwu; 
		} else {
			$def_framesperwu = $framesperwu;
		}
		if($frame_size==0) {
			$frame_size = $def_frame_size; 
		} else {
			$def_frame_size = $frame_size;
		}	
		$itermax=$def_framesperwu;

		print LOG "\tdef_frame_size=$def_frame_size\n\tdef_framesperwu=$def_framesperwu\n\titermax=$itermax\n\tdef_md_timestep=$def_md_timestep\n";

		$edr = "$xtc_base_dir/frame$f.edr";
		$tpr = "$xtc_base_dir/frame0.tpr";

		print LOG "Processing xtc=$work_unit\n";
		print LOG "Processing edr=$edr\n";
		print LOG "Processing tpr=$tpr\n";

		if((-e $edr) && (-e $tpr)) {

			# define (input) filenames #
			$xtcfile = "$sandbox_dir/current_frame.xtc";
			$edrfile = "$sandbox_dir/current_frame.edr"; 
			$tprfile = "$sandbox_dir/current_frame.tpr";
			$xtcfile2= "$sandbox_dir/current_frame2.xtc";
			$topfile = "$gro_dir/proj$pro.top";
			$mdpfile = "$gro_dir/proj$pro.mdp";
			
			system("cp $work_unit $xtcfile");
			system("cp $edr $edrfile");
			system("cp $tpr $tprfile");

			# define (output) filenames #
			$rmsdfile = "$sandbox_dir/rmsd.xvg";
			$gyratefile = "$sandbox_dir/gyrate.xvg";
			$dsspfile = "$sandbox_dir/ss.xpm";

			if($project_name eq "BCHE"){
				$Enzyme_gro = "BCHE_native.gro";
				$Enzyme_ndx = "BCHE_native.ndx";
			}
			
			# generate gromacs data files #
			# and a new waterless xtc #
			# rmsd from native & Rg & dssp #
			system("echo 1 | $bin_dir/trjconv -f $xtcfile -s $tprfile -o $xtcfile2");
			system("echo 1 1 1 | $bin_dir/g_rms -s $Enzyme_gro -f $xtcfile -o $rmsdfile");
			system("echo 1 | $bin_dir/g_gyrate -s $tprfile -f $xtcfile -o $gyratefile");
			system("echo 1 | $bin_dir/do_dssp -f $xtcfile2 -s $tprfile -o $dsspfile");
			
			################ read the frames and renumber as needed ###################     
			for($iter = 0; $iter < $itermax; $iter++) { 
				$rms{$iter} 	= 0; 
				$radgyr{$iter} 	= 0;
				$Eint{$iter} 	= 0;
				$dssp{$iter} 	= '';
				$dssp_out{$iter}= ''; 
				$Nhelix{$iter} 	= 0;		
				$Nbeta{$iter} 	= 0;		
				$Ncoil{$iter} 	= 0;		
			}

			# get rmsd's from relaxed structure using g_rms #
			unless(open(RMS,"<", $rmsdfile)) {
				print LOGFILE "[ERROR] When attempting to open $rmsdfile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close(LOG);
				system("rm $lock");
				die;
			}
			$iter=0;
			while($line=<RMS>){
				chomp $line;
				for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
				@lined = split(/ /,$line);
				if(@lined[0] =~ /\d+/) {
					if($iter>0){
					# to check for extra t_zero line #
						if($lined[0] == $oldline) { 
						$oldline = $lined[0]; 
						next;
					}
					}
					$oldline = $lined[0]; 
				$tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu); # in sequential frame # ... ie. [201..399] for frame1.xxx
				$rms1{$tim} = @lined[1] * $nm2A;
				$iter++;
				}
			}
			close(RMS);

			# get chain Rg using g_gyrate # 
			unless(open(RG,"<", $gyratefile)) {
				print LOGFILE "[ERROR] When attempting to open $gyratefile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close(LOG);
				system("rm $lock");
				die;
			}
			$iter=0;
			while($line=<RG>){
				chomp $line;
				for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
				@lined = split(/ /,$line);
				if(@lined[0] =~ /\d+/) {
					if($iter>0){
						# to check for extra t_zero line #
						if($lined[0] == $oldline) {
							$oldline = $lined[0];
							next;
						}
					}
					$oldline = $lined[0];
					$tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu);
					$radgyr{$tim} = @lined[1] * $nm2A;
					$iter++;
				}
			}
			close(RG);

			# get Eint .edr files #
			# unless(open(EDR,"<", "?")) {
			# 	print LOGFILE "[ERROR] When attempting to open ? for xtc=$work_unit. Unsetting lock and exiting...\n";
			# 	close(LOG);
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
			$iter=0;
			$sstmp = "$sandbox_dir/ss.tmp";
			`tail -522 $dsspfile > $sstmp`; # 522 signifies # of residues DSSP is analyzing
			for($ii = 0; $ii <= $framesperwu; $ii++) {
				$Nhelix{$ii} = 0;
				$Nalpha{$ii} = 0;
				$Nbeta{$ii} = 0;
				$Npi{$ii} = 0;
				$Ncoil{$ii} = 0;
			}
			unless(open(DSSP,"<" $sstmp)) {
				print LOGFILE "[ERROR] When attempting to open $sstmp for xtc=$work_unit. Unsetting lock and exiting...\n";
				close(LOG);
				system("rm $lock");
				die;
			}
			while($line=<DSSP>){
				chomp $line;
				for($line) { s/\"//; s/\,//;  s/\"//; }
				@newline = split(//,$line);
				for($ii = 0; $ii < $framesperwu; $ii++) { 
					# each dssp letter is specified as $dssp{res,time} #
					$dssp{$iter,$ii} = $newline[$ii];
				}
				$iter++;	
			}
			$resiter = $iter;
			
			for($ii = 0; $ii < $framesperwu; $ii++) { 
				for($iter = 0; $iter < $resiter; $iter++) { 
					if($dssp{$iter,$ii} eq "H"){ $Nhelix{$ii}++; }
					if($dssp{$iter,$ii} eq "G"){ $Nhelix{$ii}++; }
					if($dssp{$iter,$ii} eq "I"){ $Nhelix{$ii}++; }
					if(($dssp{$iter,$ii} eq "B")||($dssp{$iter,$ii} eq "E")){ $Nbeta{$ii}++; }
					if(($dssp{$iter,$ii} eq "~")||($dssp{$iter,$ii} eq "S")||($dssp{$iter,$ii} eq "T")){ $Ncoil{$ii}++; }
				}
			}

			for($ii = 0; $ii < $framesperwu; $ii++) { 
				@dssp_str = '';
				for($iter = 0; $iter < $resiter; $iter++) { 
					push @dssp_str,$dssp{$iter,$ii};
				}	
				$dssp_out{$ii} = "@dssp_str";
				for($dssp_out{$ii}){ s/ //g; }
			}

			# adjust the time ;>) #
			for($iter=0; $iter<$itermax; $iter++){
				$framenew[$iter] = $f * $def_framesperwu + $iter;	 
				$tim = $framenew[$iter];
				$dssp_out2{$tim} = $dssp_out{$iter};
				$Nhelix2{$tim} = $Nhelix{$iter};
				$Nbeta2{$tim}  = $Nbeta{$iter};
				$Ncoil2{$tim}  = $Ncoil{$iter}; # to disclude terminal residues!!!
			}
			# if(!($debug)){ system("rm *.xvg current_frame.* *.trr *.edr dd* *2.xtc md.log mdout.mdp energy.tpr \\#* ss.xpm ss.tmp gromp*"); }
		}
	} else {
		print LOGFILE "[ERROR] MISSING XTC=$work_unit. Unsetting lock and exiting...\n";
		close(LOG);
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
# 		print LOG "Query $query\n\n";
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
# close(LOG);
# if(!($debug)){ system("mv $logfile DONE/; mv $infile LOGS/; rm debug.log"); }
