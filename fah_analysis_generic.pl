#!/usr/bin/perl
use DBI;
use Scalar::Util qw(looks_like_number);

# Perl trim function to remove whitespace from the start and end of the string
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+|\s+$//g;
	return $string;
}

# Exit on error function
sub exit_on_error {
	my($s_dir, $q_file, @q_lines) = @_;
	system("rm $s_dir/*");
	open my $NEW_Q, ">", $q_file;
	$curr_q_line = pop(@q_lines);
	print $NEW_Q $curr_q_line . "\n";
	foreach (@q_lines) {
		print $NEW_Q $_ . "\n";
	}
	close($NEW_Q);
}

#######################	setup I/O ############################
# Dirs #
my $home_dir = "/home/server/server2";
my $analysis_dir = "$home_dir/analysis";
my $fah_files = "$analysis_dir/fah-files";
my $sandbox_dir = "$analysis_dir/sandbox";
my $log_dir = "$analysis_dir/analyzer-logs";
# Files #
my $log = "$log_dir/analyzer.log";
my $queue = "$analysis_dir/queue_test.txt";
my $work_finished = "$analysis_dir/done_test.txt";
my $lock = "$analysis_dir/lock.txt";
# DB #
my $dbserver = "134.139.52.4:3306";

#######################	Open Logger ############################
# This script always writes to a log file
# Status updates, warnings and errors will appear in this file
open my $LOG, ">>", $log || die "\nError: can't open analyzer.log\n\n";

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
	unless(open $WORK_FINISHED, ">>", $work_finished) {
		print $LOG "[ERROR] Unable to open work_finished=$work_finished. Unsetting lock and exiting...\n";
		system("rm $lock");
		die;
	}
} else {
	print $LOG "[ERROR] work_finished=$work_finished does not exist. Check for erros in the configuration. Unsetting lock and exiting...\n";
	close($LOG);
	system("rm $lock");
	die;
}
print $LOG "Sanity check: queue & work_finished passed. Continuing...\n";

#################### get frame info #########################
while ($queue_line = shift(@queue_lines)) { 
	my @queue_data = split(/\t/, $queue_line);
	my $project_name = trim($queue_data[0]);
	my $work_unit = trim($queue_data[1]);
	
	#################### .xtc check ###################
	if (-e $work_unit) {
		print $LOG "Found WU=$work_unit\n";
		@work_unit_information = split(/\//, $work_unit);
		foreach(@work_unit_information) {
			if (index($_, "frame") != -1) {
				$xtc_base_dir = substr($work_unit, 0, -(length($_) + 1));
				@xtc_split = split(/\./, $_); 
				$f = substr($xtc_split[0], 5);
			} elsif(index($_, "PROJ") != -1) {
				$pro = substr($_, 4);
			} elsif(index($_, "RUN") != -1) {
				$r = substr($_, 3);
			} elsif(index($_, "CLONE") != -1) {
				$cln = substr($_, 5);
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
		if((-e $edr) && (-e $tpr)) {
			print $LOG "Processing xtc=$work_unit\n";
			print $LOG "Processing edr=$edr\n";
			print $LOG "Processing tpr=$tpr\n";
			
			######################
			# BCHE table format  #
			######################
			# proj INT NOT NULL, # 
			# run INT NOT NULL,  #
			# clone INT NOT NULL,# 
			# frame INT NOT NULL,#
			# rmsd_pro FLOAT,    #
			# rmsd_complex FLOAT,#
			# mindist FLOAT,     #
			# rg_pro FLOAT,      #
			# E_vdw FLOAT,       #
			# E_qq FLOAT,        #
			# dssp VARCHAR(550), #
			# Nhelix INT,        #
			# Nbeta INT,         #
			# Ncoil INT,         #
			# dateacquried DATE, #
			# timeacquired TIME  #
			######################
			my %insert_data;

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

			# get protein rmsd's #
			unless(open $RMS,"<", $rmsdfile) {
				print $LOG "[ERROR] When attempting to open $rmsdfile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			}
			chomp(@rmsd_lines = <$RMS>);
			close($RMS);
			print $LOG "Getting protein RMSD's...\n";
			foreach (@rmsd_lines){
				if (index($_, "#") != -1) {
					next;
				}
				if (index($_, "@") != -1) {
					next;
				}
				$rmsd_trim_line = trim($_);
				@rmsd_values = split(/\s+/, $rmsd_trim_line);
				$rmsd_time = int($rmsd_values[0]);
				$rmsd_value = $rmsd_values[1];
				$insert_data{"$rmsd_time"}[0] = $rmsd_value; 
			}

			# get complex rmsd's #
			unless(open $RMS_COMPLEX,"<", $rmsdcomplexfile) {
				print $LOG "[ERROR] When attempting to open $rmsdcomplexfile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			}
			chomp(@rmsd_complex_lines = <$RMS_COMPLEX>);
			close($RMS_COMPLEX);
			print $LOG "Getting complex RMSD's...\n";
			foreach (@rmsd_complex_lines){
				if (index($_, "#") != -1) {
					next;
				}
				if (index($_, "@") != -1) {
					next;
				}
				$rmsd_complex_trim_line = trim($_);
				@rmsd_complex_values = split(/\s+/, $rmsd_complex_trim_line);
				$rmsd_complex_time = int($rmsd_complex_values[0]);
				$rmsd_complex_value = $rmsd_complex_values[1];
				$insert_data{"$rmsd_complex_time"}[1] = $rmsd_complex_value; 
			}
			
			# get mindist of complex
			if($pro eq "8200") {
 				foreach my $key (keys %insert_data) {
					$insert_data{$key}[2] = '0.0';
				}
			} else {
				unless(open $MINDIST,"<", $mindistfile) {
					print $LOG "[ERROR] When attempting to open $mindistfile for xtc=$work_unit. Unsetting lock and exiting...\n";
					close($LOG);
					close($WORK_FINISHED);
					exit_on_error($sandbox_dir, $queue, @queue_lines);
					system("rm $lock");
					die;
				}
				chomp(@mindist_lines = <$MINDIST>);
				close($MINDIST);
				print $LOG "Getting mindist of complex...\n";
				foreach (@mindist_lines){
					if (index($_, "#") != -1) {
						next;
					}
					if (index($_, "@") != -1) {
						next;
					}
					$mindist_trim_line = trim($_);
					@mindist_values = split(/\s+/, $mindist_trim_line);
					$mindist_time = int(sprintf("%.10g", $mindist_values[0]));
					$mindist_value = sprintf("%.10g", $mindist_values[1]);
					$insert_data{"$mindist_time"}[2] = $mindist_value; 
				}
			}

			# get rg's #
			unless(open $RG,"<", $gyratefile) {
				print $LOG "[ERROR] When attempting to open $gyratefile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			}
			chomp(@rg_lines = <$RG>);
			close($RG);
			print $LOG "Getting RG's...\n";
			foreach (@rg_lines){
				if (index($_, "#") != -1) {
					next;
				}
				if (index($_, "@") != -1) {
					next;
				}
				$rg_trim_line = trim($_);
				@rg_values = split(/\s+/, $rg_trim_line);
				$rg_time = int($rg_values[0]);
				$rg_value = $rg_values[1];
				$insert_data{"$rg_time"}[3] = $rg_value;
			}

			# get vdW and QQ energies #
			unless(open $ENERGY,"<", $energyfile) {
				print $LOG "[ERROR] When attempting to open $energyfile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			}
			chomp(@energy_lines = <$ENERGY>);
			close($ENERGY);
			print $LOG "Getting vdW and QQ energies...\n";
			foreach (@energy_lines){
				if (index($_, "#") != -1) {
					next;
				}
				if (index($_, "@") != -1) {
					next;
				}
				$energy_trim_line = trim($_);
				@energy_values = split(/\s+/, $energy_trim_line);
				$energy_time = int($energy_values[0]);
				$qq_value = $energy_values[1];
				$vdw_value = $energy_values[2];
				$insert_data{"$energy_time"}[4] = $vdw_value;
				$insert_data{"$energy_time"}[5] = $qq_value;
			}
			
			# get dssp string #
			keys %insert_data;
			foreach my $key (keys %insert_data) {
				$insert_data{$key}[6] = '';
			}
			unless(open $DSSP,"<", $dsspfile) {
				print $LOG "[ERROR] When attempting to open $dsspfile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			}
			chomp(@dssp_lines = <$DSSP>);
			close($DSSP);
			print $LOG "Getting dssp string...\n";
			@dssp_x_axis;
			$dssp_string = "";
DSSP_OUTER: foreach (@dssp_lines){
				if (index($_, "x-axis") != -1) {
					$_ =~ s/\*//g;
					$_ =~ s/\///g;
					@_split = split(/:/, $_);
					$x_vals_str = trim($_split[1]);
					@dssp_x_axis = split(/\s+/, $x_vals_str);
					next;
				}
				if (index($_, "*") != -1) {
					next;
				}
				for my $c (split //, $_) {
					if (looks_like_number($c)) {
						next DSSP_OUTER;
					}
				}
				$dssp_trim_line = trim($_);
				$dssp_trim_line =~ s/,//;
				$dssp_trim_line =~ s/"//g;
				@dssp_vals = split(//, $dssp_trim_line);
				for (my $i = 0; $i < scalar(@dssp_x_axis); $i++) {
    				$insert_data{$dssp_x_axis[$i]}[6] = $insert_data{$dssp_x_axis[$i]}[6] . $dssp_vals[$i];
				}
			}

			# get Nhelix, Nbeta, and Nccoil #
			unless(open $DSSP_COUNTS,"<", $dsspcountsfile) {
				print $LOG "[ERROR] When attempting to open $dsspcountsfile for xtc=$work_unit. Unsetting lock and exiting...\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			}
			chomp(@dssp_counts_lines = <$DSSP_COUNTS>);
			close($DSSP_COUNTS);
			print $LOG "Getting Nhelix, Nbeta, and Nccoil...\n";
			foreach (@dssp_counts_lines){
				if (index($_, "#") != -1) {
					next;
				}
				if (index($_, "@") != -1) {
					next;
				}
				$dssp_counts_trim_line = trim($_);
				@dssp_counts_values = split(/\s+/, $dssp_counts_trim_line);
				$dssp_counts_time = int($dssp_counts_values[0]);
				$coil_value =  int($dssp_counts_values[2]);
				$bsheet_value =  int($dssp_counts_values[3]);
				$bbridge_value =  int($dssp_counts_values[4]);
				$bend_value =  int($dssp_counts_values[5]);
				$turn_value =  int($dssp_counts_values[6]);
				$ahelix_value =  int($dssp_counts_values[7]);
				$five_helix_value =  int($dssp_counts_values[8]);
				$three_helix_value =  int($dssp_counts_values[9]);
				$nhelix_val = $ahelix_value + $five_helix_value + $three_helix_value;
				$nbeta_val = $bsheet_value + $bbridge_value;
				$ncoil_val = $coil_value + $bend_value + $turn_value;
				$insert_data{"$dssp_counts_time"}[7] = $nhelix_val;
				$insert_data{"$dssp_counts_time"}[8] = $nbeta_val;
				$insert_data{"$dssp_counts_time"}[9] = $ncoil_val;
			}

			############## MYSQL ###################
			print $LOG "Obtained data points for all attributes, inserting into database...\n";
			# Connecting to the db hosted on banana #
			my $dbh = DBI->connect("DBI:mysql:$project_name:$dbserver","server","", { AutoCommit => 0 }) or do {
				print $LOG "[ERROR] Can't connect to mysql database on $dbserver.\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			};
			print $LOG "Database connection established\n";
			keys %insert_data;
			foreach my $k (keys %insert_data) {
				@v = @{$insert_data{$k}};
				# On duplicate primary key log and ignore
				$sql_str = "INSERT INTO $project_name (proj,run,clone,frame,rmsd_pro,rmsd_complex,mindist,rg_pro,E_vdw,E_qq,dssp,Nhelix,Nbeta,Ncoil,dateacquried,timeacquired) VALUES($pro,$r,$cln,$k,$v[0],$v[1],$v[2],$v[3],$v[4],$v[5],'$v[6]',$v[7],$v[8],$v[9],'$date','$time')";
				$statement = $dbh->prepare($sql_str) or do{
					$stmnt_err = $statement->errstr();
					print $LOG "[ERROR] On preparing SQL statement=$sql_str : $stmnt_err Unsetting lock, and exiting...\n";
					close($LOG);
					close($WORK_FINISHED);
					exit_on_error($sandbox_dir, $queue, @queue_lines);
					system("rm $lock");
					die;
				};
				$statement->execute() or do {
					$stmnt_err = $statement->errstr();
					print $LOG "[WARNING] On insert=$sql_str: $stmnt_err";
				};
			}
			$dbh->commit() or do {
				print $LOG "[ERROR] On committing data to database.Unsetting lock, and exiting...\n";
				close($LOG);
				close($WORK_FINISHED);
				exit_on_error($sandbox_dir, $queue, @queue_lines);
				system("rm $lock");
				die;
			};
			print $LOG "Committed inserts to database.\n";
			# Add entry to work finished #
			print $WORK_FINISHED $queue_line . "\n";
			print $LOG "Successfully analyzed and inserted data for WU=$work_unit. Added this entry $work_finished.\n";
			# Clear sandbox #
			system("rm $sandbox_dir/*");
		} else {
			print $LOG "[ERROR] MISSING EDR=$edr or TPR=$tpr. Unsetting lock and exiting...\n";
			close($LOG);
			close($WORK_FINISHED);
			exit_on_error($sandbox_dir, $queue, @queue_lines);
			system("rm $lock");
			die;
		}
	} else {
		print $LOG "[ERROR] MISSING XTC=$work_unit. Unsetting lock and exiting...\n";
		close($LOG);
		close($WORK_FINISHED);
		exit_on_error($sandbox_dir, $queue, @queue_lines);
		system("rm $lock");
		die;
	}
}
# Clearing the queue #
open my $QUEUE_CLEAR, ">", $queue or do {
	print $LOG "[ERROR] Unable to clear queue. This error is unexpected and should be investigated. Unsetting lock and exiting...\n";
	close($LOG);
	close($WORK_FINISHED);
	system("rm $lock");
	die;
};
print $LOG "Cleared the queue.\n";
close($QUEUE_CLEAR);
close($WORK_FINISHED);
print $LOG "Anylsis complete. Exiting...\n";
close($LOG);
system("rm $lock");
exit;
