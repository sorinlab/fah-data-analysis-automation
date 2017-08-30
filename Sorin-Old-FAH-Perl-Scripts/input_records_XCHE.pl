#!/usr/bin/perl
use DBI; 
$updated = "07-15-09"; 

# this script always writes to a debug file, which will be left if the script crashes 
# debug = 1 saves debug and log.done files in the analysis directory (no mysql) 
# debug = 0 deletes these and reports to the mysql database
$debug = 0;
open(DEBUG,">debug.log") || die "\nError: can't open debug.log\n\n";
# check if the WU has been analyzed to save time (already in mysql DB)
$checkprev = 1;


######### defaults stuff ###########
# if not provided in projXXXX.conf file
$def_frame_size = 100; # time between frames in ps #
$def_framesperwu = 50; 
$def_md_timestep = 2.0; # in fs
$def_proj_min = 1740;
$def_proj_max = 1760;
$dir = "/home/server/server2/analysis/ACHE"; # two types of enzyme, maybe two folders?
$nm2A = 10.0; # nm to Angstrom conversion
$AChE=0; 
$BChE=0;


#######################	setup I/O ############################
$home_dir = "/home/server/server2";
$bin_dir = "/home/server/server2/analysis/bin";
$gro_dir = "/home/server/server2/projects";
$data_dir = "$home_dir/data";	
$analysis_dir = "$home_dir/analysis";								
system("rm $analysis_dir/job_finished");
system("touch $analysis_dir/running_flag");


################ check dbserver and input files  ######################
$dbserver = `cat $analysis_dir/dbserver`; # these `` mean "run as if on a command line interface"
chomp $dbserver;
if (!($dbserver)) { system("/bin/rm $analysis_dir/running_flag"); die "Requires dbserver\n"; }
$infile = shift(@ARGV) or die "\n\tRequires List of frames run,clone,frame run,clone,frame2 . . .\n\n";
# check that $infile is not empty #
$infil_size = `wc $infile`;
for($infil_size) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
@lined = split(/ /,$infil_size);
$infile_size = @lined[0];
$logfile = "$infile.done";
open(LOGFILE,">$logfile") or die "Can't open log file $logfile\n";


#################### get frame info & open .db logfile #########################
if($infile_size > 0) {

  $numlines = 0;
  open(INFILE,"$infile");
  LINE: while(<INFILE>) {
     $numlines++;
     @line = split;
     $nolog = 0; $window = ""; $clientip = "";  $clientname = ""; #nolog useless?

     if(($line[0] eq "C2")||($line[0] eq "S2")){
       $window = $line[5];  $clientip = $line[4];  $clientname = $line[1]; $macID = $line[6];
     }elsif(($line[0] eq "C3")||($line[0] eq "B1")||($line[0] eq "C6")){
       $window = $line[7];  $clientip = $line[6];  $clientname = $line[1]; $macID = $line[3];
     }else{
       print LOGFILE "Did not recognize the input type on line $numlines: @line ... ";
       die;
     }

     # if window was not properly detected (i.e. if there was a username with a space, etc)
     # detect the window properly for further processing ...
     @test = split(//,$window);
     if($test[0] ne "\(") {
        print LOGFILE "INCORRECT WINDOW DETECTION ... trying again ... ";
        for($num=0;$num<=$#line;$num++){
          @test = split(//,@line[$num]);
          if($test[0] eq "\("){ $window = @line[$num]; }
        }
        print LOGFILE "WINDOW $window detected ... ";
     }

     if (!($window)) { print LOGFILE "Did not get crucial information for record: line $numlines\n"; next LINE; }
     print STDERR "window $window\n";
     $window =~ s/.*\(//g;
     $window =~ s/\)//g;
     chomp $window;
     @input = map { split ',' } $window; 
     $pro = $input[0];
     $r = $input[1];
     $c = $input[3];
     $f = $input[2];

     open(CONF,"<$home_dir/CONFS/proj$pro.conf") || die "Error: can't get vital info from .conf file\n\n";
     while(defined($line = <CONF>)) {
           chomp $line;
           for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
           @linein = split(/ /,$line);
           if(@linein[0] eq 'MD_TIMESTEP'){ $md_timestep =  @linein[1]; }
           if(@linein[0] eq 'DB_NUM_FRAMES'){ $framesperwu = @linein[1]; }
           if(@linein[0] eq 'DB_TEMPORAL_RESOLUTION'){ $frame_size = @linein[1]; }
     }
     close(CONF);


#################### check DB for previous analysis ###################
 # check for last expected frame in the WU (i.e. for complete processing)
 $testframe = (($f + 1) * $framesperwu) - 1;
 $doneprev = 0;

 if($checkprev == 1){
   my $db = DBI->connect("DBI:mysql:project$pro:$dbserver",server,"") or die "Can't connect to FAH database on $dbserver\n";
   $statement = $db->prepare("SELECT * FROM frames WHERE (run = '$r' AND clone = '$c' AND frame = '$testframe')");
   $statement->execute;
   $existingrows = $statement->rows;
   if ($existingrows) {
        $doneprev = 1;
        print LOGFILE "$window done previously\n";
   }
  }

  if($doneprev == 0){


#################### project/file check ###################
     if (($pro>=$def_proj_min)&&($pro<=$def_proj_max)) {
	 $projectID = $pro;
	 if (-e "current_frame.pdb") { system("/bin/rm current_frame.*"); }
	 if (!(-e "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc")) {print LOGFILE "MISSING XTC FILE! $data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc\n"; next LINE; }
	 
	 # distinguish between BChE and AChE for RgARG and RMSD calcs #
	 if(($pro>1739)&&($pro<1750)){
	   $BChE = 1; $AChE = 0;
	 }elsif(($pro>1749)&&($pro<1760)){
	   $BChE = 0; $AChE = 1;   
	 }


#################### DATETIME ########################
        $date = `ls -l --full-time $data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc | awk '{print \$6" "\$7}'`;
        chomp $date;
        for($date) {  s/\.000000000//g; }
        @datenew = split(/\./,$date);
        $timeaq = "@datenew[0]"; # $timeaq .= "-$month"; $timeaq .= "-$tempor1[7] $tempor1[8]";
	#print STDOUT "$timeaq\n\n";


############### get/prep the gromacs files for analysis  ##############
	 if($md_timestep==0){ $md_timestep = $def_md_timestep;
	 }else{ $def_md_timestep = $md_timestep; }
	 if($framesperwu==0){ $framesperwu = $def_framesperwu; 
	 }else{ $def_framesperwu = $framesperwu; }
	 if($frame_size==0){ $frame_size = $def_frame_size; 
	 }else{ $def_frame_size = $frame_size; }	
         $itermax=$def_framesperwu;

	 print DEBUG "def_frame_size=$def_frame_size\ndef_framesperwu=$def_framesperwu\nitermax=$itermax\ndef_md_timestep=$def_md_timestep\n\n";

 	 $fil1 = "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.xtc";
	 $fil2 = "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame$f.edr";
	 $fil3 = "$data_dir/PROJ$pro/RUN$r/CLONE$c/frame0.tpr";

	 print DEBUG "processing RUN$r/CLONE$c/frame$f\n$fil1\n$fil2\n$fil3\n";
	 if((-e $fil1)&&(-e $fil2)&&(-e $fil3)){
	
	   system("cp $fil1 ./current_frame.xtc");
	   system("cp $fil2 ./current_frame.edr");
	   system("cp $fil3 ./current_frame.tpr");

	   # define filenames #
	   $xtcfile = "current_frame.xtc";
	   $xtcfile2= "current_frame2.xtc";
	   $tprfile = "current_frame.tpr";
	   $edrfile = "current_frame.edr"; 
	   $topfile = "$gro_dir/proj$pro".".top";
           $mdpfile = "$gro_dir/proj$pro".".mdp";

	   if($BChE){
		$Enzyme_gro = "BCHE_native.gro"; #change for BChE and AChE#
		$Enzyme_ndx = "BCHE_native.ndx";
	   }elsif($AChE){
		$Enzyme_gro = "ACHE_native.gro";
		$Enzyme_ndx = "ACHE_native.ndx";
	   }
	 
	   # generate gromacs data files #
	   # and a new waterless xtc #
	   # rmsd from native & Rg & dssp #
	   system("echo 1 | $bin_dir/trjconv -f $xtcfile -s $tprfile -o $xtcfile2");	
	   system("echo 1 1 1 | $bin_dir/g_rms -s $Enzyme_gro -f $xtcfile" );
	   system("echo 1 | $bin_dir/g_gyrate -s $tprfile -f $xtcfile");  #Remove if($FS); need -n $Enzyme_ndx
	   system("echo 1 | $bin_dir/do_dssp -f $xtcfile2 -s $tprfile");

	   # get the polymeric potential by subtracting all other-other terms #
	   # this is old code ... ignore for now if commented out!
	   #`$bin_dir/grompp -f $mdpfile -c current_frame.tpr -o energy.tpr -p $topfile`;
           #`$bin_dir/mdrun -s energy.tpr -rerun current_frame.xtc`;
           #`echo \"9 0\" | $bin_dir/g_energy -f current_frame.edr`;


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
	   open(RMS,"<rmsd.xvg") || print LOGFILE "Error reading from rmsd.xvg for p$pro r$r c$c f$f ... ";
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
	   $newiter = $iter;


	   # get chain Rg using g_gyrate # 
	   open(RG,"<gyrate.xvg") || print LOGFILE "Error reading from gyrate.xvg for p$pro r$r c$c f$f ... ";
	   $iter=0;                   #should be gyrate.xvg since I didn't move Rg to gyrate?
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
	   #open(EDR,"<energy.xvg") || print LOGFILE "Error reading from energy.xvg for p$pro r$r c$c f$f ... ";
	   #$iter=0;
	   #while($line=<EDR>){
	   #  chomp $line;
	   #  for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
	   #  @lined = split(/ /,$line);
	   #  if((@lined[1] =~ /\d+/)&&(@lined[0] ne "\@")) {
	   #	if($iter>0){
           #        # to check for extra t_zero line #
           #        if($lined[1] == $oldline) {
           #          $oldline = $lined[1];
           #          next;
           #        }
           #      }
           #      $oldline = $lined[0];
	   #	 # need in sequential frame # ... ie. [11..19] for frame1.xxx
           #	 $tim = (int($oldline/$def_frame_size)) + ($f * $def_framesperwu); 
           #	 $Epot{$tim} = @lined[1] - @lined[2] - @lined[3] - @lined[4] - @lined[5];
	   #	 $iter++;
	   #  }
	   #}
	   #close(EDR);

	   # get dssp data #
	   $iter=0;
	   `tail -522 ss.xpm > ss.tmp`; # 522 signifies # of residues DSSP is analyzing
	   for($ii = 0; $ii <= $framesperwu; $ii++) { $Nhelix{$ii}=0; $Nalpha{$ii} = 0; $Nbeta{$ii} = 0; $Npi{$ii} = 0; $Ncoil{$ii} = 0; }
	   open(DSSP,"<ss.tmp") || print LOGFILE "Error reading from ss.tmp for p$pro r$r c$c f$f ... ";
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
	   if(!($debug)){ system("rm *.xvg current_frame.* *.trr *.edr dd* *2.xtc md.log mdout.mdp energy.tpr \\#* ss.xpm ss.tmp gromp*"); }
	 }
	 
############## MYSQL stuff: report values to logfile DB ###################
	 
	 print LOGFILE "$window $clientname $clientip ... ";

         if(!($debug)){
           $dbh = DBI->connect("DBI:mysql:project$projectID:$dbserver",server,"") or print LOGFILE "Can't connect to FAH database on $dbserver ... ";
	 }	 
	 for($iter=0;$iter<$itermax;$iter++){	     
	     $frame = $framenew[$iter];
	     if(!($debug)){
	       $statement = $dbh->prepare("SELECT * FROM frames WHERE (run = '$r' AND clone = '$c' AND frame = '$frame')");
	       $statement->execute;
	       $existingrows = $statement->rows;
    
	       if ($existingrows) { 
	         if($iter == 0){ print LOGFILE "SKIPPING INSERT - JUST UPDATE ... "; }
	       } else { 
	         $statement = $dbh->prepare("INSERT INTO frames (run, clone, frame) VALUES ('$r','$c','$frame')");	
	         $statement->execute;
	       }
	     }
	     $query = "UPDATE frames SET rmsd = '$rms1{$frame}', Eint = '$Eint{$frame}', radiusgyr = '$radgyr{$frame}', dssp = '$dssp_out2{$frame}', Nhelix = '$Nhelix2{$frame}', Nbeta = '$Nbeta2{$frame}', Ncoil = '$Ncoil2{$frame}', acquired = '$timeaq'";
	     $query .= " WHERE ( run = '$r' AND clone = '$c' AND frame = '$frame' )"; 
	     print DEBUG "Query $query\n\n";
	     if(!($debug)){
	       $statement = $dbh->prepare("$query");
	       $statement->execute;
	       $statement->finish;
	     }
	 }
	 print LOGFILE "\n";
         if(!($debug)){ $dbh->disconnect; }     
	 
      }  # ends if ($proID) line
    }    # ends if($doneprev) loop     
  }  # ends while infile loop
} # ends if $infile_size > 0 loop

#print STDERR "Finishing input_records.prl $infile\n";
system("touch $analysis_dir/job_finished");
system("/bin/rm $analysis_dir/running_flag");
close(INFILE);
close(LOGFILE);
close(DEBUG);
if(!($debug)){ system("mv $logfile DONE/; mv $infile LOGS/; rm debug.log"); }
