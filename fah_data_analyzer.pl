#!/usr/bin/perl
use DBI; 
$updated = "08-16-17"; 

#######################	setup I/O ############################
$home_dir = "/home/xavier/git-repositories";
$analysis_dir = "$home_dir/fah-data-analysis-automation";								
$bin_dir = "$analysis_dir/bin";
$gro_dir = "$analysis_dir/gro-files";
$log = "$analysis_dir/analyzer-logs/analyzer.log";
$data_dir = "$home_dir/data"; # To be removed...
$queue = "$analysis_dir/queue.txt";
$work_finished = "$analysis_dir/done.txt";
$lock = "$analysis_dir/lock.txt";
$sandbox = "$analysis_dir/sandbox";

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
$def_proj_min = 1740; # To be removed...
$def_proj_max = 1760; # To be removed

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
	close $handle;
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
$sample_queue_line = $queue_lines[0];
print LOG "$sample_queue_line\n";
close(LOG);
system("rm $lock");
die;

# TO-DO: Implement below

#################### get frame info & open .db logfile #########################
# if($infile_size > 0) {

#   $numlines = 0;
#   open(INFILE,"$infile");
#   LINE: while(<INFILE>) {
#      $numlines++;
#      @line = split;
#      $nolog = 0; $window = ""; $clientip = "";  $clientname = ""; #nolog useless?

#      if(($line[0] eq "C2")||($line[0] eq "S2")){
#        $window = $line[5];  $clientip = $line[4];  $clientname = $line[1]; $macID = $line[6];
#      }elsif(($line[0] eq "C3")||($line[0] eq "B1")||($line[0] eq "C6")){
#        $window = $line[7];  $clientip = $line[6];  $clientname = $line[1]; $macID = $line[3];
#      }else{
#        print LOGFILE "Did not recognize the input type on line $numlines: @line ... ";
#        die;
#      }

#      # if window was not properly detected (i.e. if there was a username with a space, etc)
#      # detect the window properly for further processing ...
#      @test = split(//,$window);
#      if($test[0] ne "\(") {
#         print LOGFILE "INCORRECT WINDOW DETECTION ... trying again ... ";
#         for($num=0;$num<=$#line;$num++){
#           @test = split(//,@line[$num]);
#           if($test[0] eq "\("){ $window = @line[$num]; }
#         }
#         print LOGFILE "WINDOW $window detected ... ";
#      }

#      if (!($window)) { print LOGFILE "Did not get crucial information for record: line $numlines\n"; next LINE; }
#      print STDERR "window $window\n";
#      $window =~ s/.*\(//g;
#      $window =~ s/\)//g;
#      chomp $window;
#      @input = map { split ',' } $window; 
#      $pro = $input[0];
#      $r = $input[1];
#      $c = $input[3];
#      $f = $input[2];

#      open(CONF,"<$home_dir/CONFS/proj$pro.conf") || die "Error: can't get vital info from .conf file\n\n";
#      while(defined($line = <CONF>)) {
#            chomp $line;
#            for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
#            @linein = split(/ /,$line);
#            if(@linein[0] eq 'MD_TIMESTEP'){ $md_timestep =  @linein[1]; }
#            if(@linein[0] eq 'DB_NUM_FRAMES'){ $framesperwu = @linein[1]; }
#            if(@linein[0] eq 'DB_TEMPORAL_RESOLUTION'){ $frame_size = @linein[1]; }
#      }
#      close(CONF);


# #################### check DB for previous analysis ###################
#  # check for last expected frame in the WU (i.e. for complete processing)
#  $testframe = (($f + 1) * $framesperwu) - 1;
#  $doneprev = 0;

#  if($checkprev == 1){
#    my $db = DBI->connect("DBI:mysql:project$pro:$dbserver",server,"") or die "Can't connect to FAH database on $dbserver\n";
#    $statement = $db->prepare("SELECT * FROM frames WHERE (run = '$r' AND clone = '$c' AND frame = '$testframe')");
#    $statement->execute;
#    $existingrows = $statement->rows;
#    if ($existingrows) {
#         $doneprev = 1;
#         print LOGFILE "$window done previously\n";
#    }
#   }

#   if($doneprev == 0){


# #################### project/file check ###################
#      if (($pro>=$def_proj_min)&&($pro<=$def_proj_max)) {
# 	 $projectID = $pro;
# 	 if (-e "current_frame.pdb") { system("/bin/rm current_frame.*"); }
# 	 if (!(-e "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc")) {print LOGFILE "MISSING XTC FILE! $data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc\n"; next LINE; }
	 
# 	 # distinguish between BChE and AChE for RgARG and RMSD calcs #
# 	 if(($pro>1739)&&($pro<1750)){
# 	   $BChE = 1; $AChE = 0;
# 	 }elsif(($pro>1749)&&($pro<1760)){
# 	   $BChE = 0; $AChE = 1;   
# 	 }


# #################### DATETIME ########################
#         $date = `ls -l --full-time $data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc | awk '{print \$6" "\$7}'`;
#         chomp $date;
#         for($date) {  s/\.000000000//g; }
#         @datenew = split(/\./,$date);
#         $timeaq = "@datenew[0]"; # $timeaq .= "-$month"; $timeaq .= "-$tempor1[7] $tempor1[8]";
# 	#print STDOUT "$timeaq\n\n";


# ############### get/prep the gromacs files for analysis  ##############
# 	 if($md_timestep==0){ $md_timestep = $def_md_timestep;
# 	 }else{ $def_md_timestep = $md_timestep; }
# 	 if($framesperwu==0){ $framesperwu = $def_framesperwu; 
# 	 }else{ $def_framesperwu = $framesperwu; }
# 	 if($frame_size==0){ $frame_size = $def_frame_size; 
# 	 }else{ $def_frame_size = $frame_size; }	
#          $itermax=$def_framesperwu;

# 	 print LOG "def_frame_size=$def_frame_size\ndef_framesperwu=$def_framesperwu\nitermax=$itermax\ndef_md_timestep=$def_md_timestep\n\n";

#  	 $fil1 = "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc";
# 	 $fil2 = "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.edr";
# 	 $fil3 = "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame0.tpr";

# 	 print LOG "processing RUN$r/CLONE$c/frame$f\n$fil1\n$fil2\n$fil3\n";
# 	 if((-e $fil1)&&(-e $fil2)&&(-e $fil3)){
	
# 	   system("cp $fil1 ./current_frame.xtc");
# 	   system("cp $fil2 ./current_frame.edr");
# 	   system("cp $fil3 ./current_frame.tpr");

# 	   # define filenames #
# 	   $xtcfile = "current_frame.xtc";
# 	   $xtcfile2= "current_frame2.xtc";
# 	   $tprfile = "current_frame.tpr";
# 	   $edrfile = "current_frame.edr"; 
# 	   $topfile = "$gro_dir/proj$pro".".top";
#            $mdpfile = "$gro_dir/proj$pro".".mdp";

# 	   if($BChE){
# 		$Enzyme_gro = "BCHE_native.gro"; #change for BChE and AChE#
# 		$Enzyme_ndx = "BCHE_native.ndx";
# 	   }elsif($AChE){
# 		$Enzyme_gro = "ACHE_native.gro";
# 		$Enzyme_ndx = "ACHE_native.ndx";
# 	   }
	 
# 	   # generate gromacs data files #
# 	   # and a new waterless xtc #
# 	   # rmsd from native & Rg & dssp #
# 	   system("echo 1 | $bin_dir/trjconv -f $xtcfile -s $tprfile -o $xtcfile2");	
# 	   system("echo 1 1 1 | $bin_dir/g_rms -s $Enzyme_gro -f $xtcfile" );
# 	   system("echo 1 | $bin_dir/g_gyrate -s $tprfile -f $xtcfile");  #Remove if($FS); need -n $Enzyme_ndx
# 	   system("echo 1 | $bin_dir/do_dssp -f $xtcfile2 -s $tprfile");

# 	   # get the polymeric potential by subtracting all other-other terms #
# 	   # this is old code ... ignore for now if commented out!
# 	   #`$bin_dir/grompp -f $mdpfile -c current_frame.tpr -o energy.tpr -p $topfile`;
#            #`$bin_dir/mdrun -s energy.tpr -rerun current_frame.xtc`;
#            #`echo \"9 0\" | $bin_dir/g_energy -f current_frame.edr`;


# ################ read the frames and renumber as needed ###################     
# 	   for($iter = 0; $iter < $itermax; $iter++) { 
# 		$rms{$iter} 	= 0; 
# 		$radgyr{$iter} 	= 0;
# 		$Eint{$iter} 	= 0;
# 		$dssp{$iter} 	= '';
# 	        $dssp_out{$iter}= ''; 
#                 $Nhelix{$iter} 	= 0;		
#                 $Nbeta{$iter} 	= 0;		
#                 $Ncoil{$iter} 	= 0;		
# 	   }


#   	   # get rmsd's from relaxed structure using g_rms #
# 	   open(RMS,"<rmsd.xvg") || print LOGFILE "Error reading from rmsd.xvg for p$pro r$r c$c f$f ... ";
# 	   $iter=0;
# 	   while($line=<RMS>){
# 	     chomp $line;
# 	     for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
# 	     @lined = split(/ /,$line);
# 	     if(@lined[0] =~ /\d+/) {
# 	         if($iter>0){
#   	           # to check for extra t_zero line #
#     	           if($lined[0] == $oldline) { 
# 	             $oldline = $lined[0]; 
# 	             next;
# 	           }
# 	         }
# 	         $oldline = $lined[0]; 
# 		 $tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu); # in sequential frame # ... ie. [201..399] for frame1.xxx
# 		 $rms1{$tim} = @lined[1] * $nm2A;
# 		 $iter++;
# 	     }
# 	   }
# 	   close(RMS);
# 	   $newiter = $iter;


# 	   # get chain Rg using g_gyrate # 
# 	   open(RG,"<gyrate.xvg") || print LOGFILE "Error reading from gyrate.xvg for p$pro r$r c$c f$f ... ";
# 	   $iter=0;                   #should be gyrate.xvg since I didn't move Rg to gyrate?
# 	   while($line=<RG>){
# 	     chomp $line;
# 	     for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
# 	     @lined = split(/ /,$line);
# 	     if(@lined[0] =~ /\d+/) {
# 		if($iter>0){
#                    # to check for extra t_zero line #
#                    if($lined[0] == $oldline) {
#                      $oldline = $lined[0];
#                      next;
#                    }
#                  }
#                  $oldline = $lined[0];
# 		 $tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu);
# 		 $radgyr{$tim} = @lined[1] * $nm2A;
# 		 $iter++;
# 	     }
# 	   }
# 	   close(RG);


# 	   # get Eint .edr files #
# 	   #open(EDR,"<energy.xvg") || print LOGFILE "Error reading from energy.xvg for p$pro r$r c$c f$f ... ";
# 	   #$iter=0;
# 	   #while($line=<EDR>){
# 	   #  chomp $line;
# 	   #  for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
# 	   #  @lined = split(/ /,$line);
# 	   #  if((@lined[1] =~ /\d+/)&&(@lined[0] ne "\@")) {
# 	   #	if($iter>0){
#            #        # to check for extra t_zero line #
#            #        if($lined[1] == $oldline) {
#            #          $oldline = $lined[1];
#            #          next;
#            #        }
#            #      }
#            #      $oldline = $lined[0];
# 	   #	 # need in sequential frame # ... ie. [11..19] for frame1.xxx
#            #	 $tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu); 
#            #	 $Epot{$tim} = @lined[1] - @lined[2] - @lined[3] - @lined[4] - @lined[5];
# 	   #	 $iter++;
# 	   #  }
# 	   #}
# 	   #close(EDR);

# 	   # get dssp data #
# 	   $iter=0;
# 	   `tail -522 ss.xpm > ss.tmp`; # 522 signifies # of residues DSSP is analyzing
# 	   for($ii = 0; $ii <= $framesperwu; $ii++) { $Nhelix{$ii}=0; $Nalpha{$ii} = 0; $Nbeta{$ii} = 0; $Npi{$ii} = 0; $Ncoil{$ii} = 0; }
# 	   open(DSSP,"<ss.tmp") || print LOGFILE "Error reading from ss.tmp for p$pro r$r c$c f$f ... ";
# 	   while($line=<DSSP>){
#  	     chomp $line;
#              for($line) { s/\"//; s/\,//;  s/\"//; }
# 	     @newline = split(//,$line);
# 	     for($ii = 0; $ii < $framesperwu; $ii++) { 
# 	       # each dssp letter is specified as $dssp{res,time} #
# 	       $dssp{$iter,$ii} = $newline[$ii];
# 	     }
# 	     $iter++;	
# 	   }
# 	   $resiter = $iter;
  	   
# 	   for($ii = 0; $ii < $framesperwu; $ii++) { 
# 	     for($iter = 0; $iter < $resiter; $iter++) { 
#                 if($dssp{$iter,$ii} eq "H"){ $Nhelix{$ii}++; }
# 	   	if($dssp{$iter,$ii} eq "G"){ $Nhelix{$ii}++; }
#   	   	if($dssp{$iter,$ii} eq "I"){ $Nhelix{$ii}++; }
#            	if(($dssp{$iter,$ii} eq "B")||($dssp{$iter,$ii} eq "E")){ $Nbeta{$ii}++; }
# 	   	if(($dssp{$iter,$ii} eq "~")||($dssp{$iter,$ii} eq "S")||($dssp{$iter,$ii} eq "T")){ $Ncoil{$ii}++; }
#  	     }  
# 	   }

# 	   for($ii = 0; $ii < $framesperwu; $ii++) { 
# 	     @dssp_str = '';
# 	     for($iter = 0; $iter < $resiter; $iter++) { 
# 	       push @dssp_str,$dssp{$iter,$ii};
# 	     }	
# 	     $dssp_out{$ii} = "@dssp_str";
# 	     for($dssp_out{$ii}){ s/ //g; }
# 	   }


# 	   # adjust the time ;>) #
# 	   for($iter=0; $iter<$itermax; $iter++){
# 	     $framenew[$iter] = $f * $def_framesperwu + $iter;	 
# 	     $tim = $framenew[$iter];
# 	     $dssp_out2{$tim} = $dssp_out{$iter};
# 	     $Nhelix2{$tim} = $Nhelix{$iter};
# 	     $Nbeta2{$tim}  = $Nbeta{$iter};
# 	     $Ncoil2{$tim}  = $Ncoil{$iter}; # to disclude terminal residues!!!
# 	   }
# 	   if(!($debug)){ system("rm *.xvg current_frame.* *.trr *.edr dd* *2.xtc md.log mdout.mdp energy.tpr \\#* ss.xpm ss.tmp gromp*"); }
# 	 }
	 
# ############## MYSQL stuff: report values to logfile DB ###################
	 
# 	 print LOGFILE "$window $clientname $clientip ... ";

#          if(!($debug)){
#            $dbh = DBI->connect("DBI:mysql:project$projectID:$dbserver",server,"") or print LOGFILE "Can't connect to FAH database on $dbserver ... ";
# 	 }	 
# 	 for($iter=0;$iter<$itermax;$iter++){	     
# 	     $frame = $framenew[$iter];
# 	     if(!($debug)){
# 	       $statement = $dbh->prepare("SELECT * FROM frames WHERE (run = '$r' AND clone = '$c' AND frame = '$frame')");
# 	       $statement->execute;
# 	       $existingrows = $statement->rows;
    
# 	       if ($existingrows) { 
# 	         if($iter == 0){ print LOGFILE "SKIPPING INSERT - JUST UPDATE ... "; }
# 	       } else { 
# 	         $statement = $dbh->prepare("INSERT INTO frames (run, clone, frame) VALUES ('$r','$c','$frame')");	
# 	         $statement->execute;
# 	       }
# 	     }
# 	     $query = "UPDATE frames SET rmsd = '$rms1{$frame}', Eint = '$Eint{$frame}', radiusgyr = '$radgyr{$frame}', dssp = '$dssp_out2{$frame}', Nhelix = '$Nhelix2{$frame}', Nbeta = '$Nbeta2{$frame}', Ncoil = '$Ncoil2{$frame}', acquired = '$timeaq'";
# 	     $query .= " WHERE ( run = '$r' AND clone = '$c' AND frame = '$frame' )"; 
# 	     print LOG "Query $query\n\n";
# 	     if(!($debug)){
# 	       $statement = $dbh->prepare("$query");
# 	       $statement->execute;
# 	       $statement->finish;
# 	     }
# 	 }
# 	 print LOGFILE "\n";
#          if(!($debug)){ $dbh->disconnect; }     
	 
#       }  # ends if ($proID) line
#     }    # ends if($doneprev) loop     
#   }  # ends while infile loop
# } # ends if $infile_size > 0 loop

# #print STDERR "Finishing input_records.prl $infile\n";
# system("touch $analysis_dir/job_finished");
# system("/bin/rm $analysis_dir/running_flag");
# close(INFILE);
# close(LOGFILE);
# close(LOG);
# if(!($debug)){ system("mv $logfile DONE/; mv $infile LOGS/; rm debug.log"); }
