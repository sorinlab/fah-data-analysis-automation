#!/usr/bin/perl
$last_updated = "6-20-08";
$ver = 30;
use DBI;
use CGI;


#########	Globals		########
$rmips = 0;
$cleanup = 1;
$max_errors=5;
$server = "134.139.127.16";
$table = "frames";
$date = `date`;  chomp $date;
$hostname  = `echo \$HOSTNAME`; chomp($hostname);
#print STDOUT "hostname $hostname\n\n";

$home          = `pwd`;
$logsdir       = "/home/server/server2/vsplogs";
$data_dir      = "/home/server/server2/data";
$error_file    = "/home/server/server2/Error.log";
$error_file_bu = "/home/server/server2/Error.log.back";
$error_file_ur = "/home/server/server2/Error.log.unresolved";
$error_ips     = "/home/server/server2/Error.ips";
$error_ips_old = "/home/server/server2/Error.ips.old";
$restart       = "/home/server/server2/Error.info";


#########	Usage		########
$input = "\n\tUsage\:  errorinfo_v$ver.pl  [rm ips (ON\|\|OFF)]  [dir list]\n\n";
$iptest = @ARGV[0] || die "$input";
if($iptest eq "ON"){ $rmips = 1; }

# get list of analysis dirs #
@dirs = ();
if(defined(@ARGV)) {
  for ($i=1; $i<=$#ARGV; $i++) { $flag = $ARGV[$i]; push @dirs,$flag; }
}

`mv $hostname.txt $hostname.txt.old`;
open(OUT,">$hostname.txt") || die "\n\tError: cannot open $hostname.txt\n\n";
print OUT "$hostname status as of $date - errorinfo_v$ver.pl @ARGV\n";
$olddate = `head -1 /home/server/server2/analysis/$hostname.txt.old | awk '{print \$5\" \"\$6\" \"\$7\" \"\$8\" \"\$9\" \"\$10}'`;
chomp $olddate;
print OUT "Changes reported from $olddate\n\n";

# get the AS weightings #
`rm serverstat.html`;
`wget  http://vspX27.stanford.edu/serverstat.html`;
$ASlist = `grep $hostname serverstat.html | grep esorin`;
$AScont = `grep "SERVER IP" serverstat.html | head -1`;

for($ASlist){ 
  s/\/TD//g; s/\/TR//g;
  #s/TD//g; 
  s/TR//g;
  s/bgcolor//g; 
  s/fdfdfd//g; s/dfdfdf//g;
  s/\=//g; s/\#//g;
}
for($AScont){ 
  s/\/TD//g; s/\/TR//g;
  #s/TD//g; 
  s/TR//g;
  s/bgcolor//g; 
  s/fdfdfd//g; s/dfdfdf//g;
  s/\=//g; s/\#//g;
}

#@ASstat = split(/\<\>/,$ASlist);
#@ASnames= split(/\<\>/,$AScont);
@ASstat = split(TD,$ASlist);
@ASnames= split(TD,$AScont);
for(@ASstat){ s/\<//g; s/\>//g; }
for(@ASnames){ s/\<//g; s/\>//g; }
$ASlen1 = @ASstat;
$ASlen2 = @ASnames;

for($jj=0;$jj<$ASlen2;$jj++){
  for(@ASnames[$jj]){ s/\<//g; s/\>//g; }
  for(@ASstat[$jj]){ s/\<//g; s/\>//g; }
  #print STDOUT "@ASnames[$jj]  @ASstat[$jj]\n";

  if(@ASnames[$jj] eq "STATUS" ){ $ASstatus = @ASstat[$jj] };
  if(@ASnames[$jj] eq "CONNECT" ){ $ASconnect = @ASstat[$jj] };
  if(@ASnames[$jj] eq "OperatingSystem" ){ $ASopsys = @ASstat[$jj] };
  if(@ASnames[$jj] eq "WEIGHT" ){ $ASweight = @ASstat[$jj] };
  if(@ASnames[$jj] eq "PROGRAM" ){ $ASprog = @ASstat[$jj] };
  if(@ASnames[$jj] eq "AssignedPort" ){ $ASports = @ASstat[$jj] };
}

$ASstatlist = "Current AS settings: 
status      connect        opsys       weight           prog         ports\n";
print OUT "$ASstatlist";
printf OUT "%-10s %-14s %-10s  %-12s     %-12s %-12s\n\n",$ASstatus,$ASconnect,$ASopsys,$ASweight,$ASprog,$ASports;


########## 	get active projects 	##########
@pros = `grep ACCEPT /home/server/server2/project.conf | grep SERVER | awk '{print \$2}'`;

$n=0;
foreach $x (@pros){ 
  $temp = $x;
  for($temp){ s/CONFS\///; }
  chomp $temp; 
  for($temp){ s/proj//; s/\.conf//; } 
  @projs[$n]=$temp;
  $n++;

  open(CONF,"</home/server/server2/CONFS/proj$temp.conf") || die "Error: can't get vital info from proj$temp.conf\n\n";
  while(defined($line = <CONF>)) {
    chomp $line;
    for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
    @linein = split(/ /,$line);
    if(@linein[0] eq 'DB_NUM_FRAMES'){ $framesperwu{$temp} = @linein[1]; }
    if(@linein[0] eq 'STATSCREDIT')  { $statscredit{$temp} = @linein[1]; }
    if(@linein[0] eq 'DESCRIPTION')  { $description{$temp} = @linein[1]; }
    if(@linein[0] eq 'MD_TIMESTEP')  { $mdtimestep{$temp}  = @linein[1]; }
    if(@linein[0] eq 'MAX_ITER')     { $maxiter{$temp}     = @linein[1]; }
  }
  close(CONF);
}  
@sjorp = reverse(@projs);
$proj_min =@projs[0];
$proj_max =@sjorp[0];


######          look at OPR/JOB/netstat         #######
chdir("/home/server/server2/");

$jobsall = `./sinfo | wc | awk '{print \$1}'`;
chomp $jobsall;
$jobsallold = `grep OPR /home/server/server2/analysis/$hostname.txt.old | grep all | awk '{print \$5}'`;
chomp $jobsallold;
print OUT "Jobs in OPR (all): $jobsall ($jobsallold)\n";

$jobswait = `./sinfo | grep wait | wc | awk '{print \$1}'`;
chomp $jobswait;
$jobswaitold = `grep OPR /home/server/server2/analysis/$hostname.txt.old | grep \"wait\" | awk '{print \$5}'`;
chomp $jobswaitold;
print OUT "Jobs in OPR (wait): $jobswait ($jobswaitold)\n";

$jobsdisc = `./sinfo | grep discard | wc | awk '{print \$1}'`;
chomp $jobsdisc;
$jobsdiscold = `grep OPR /home/server/server2/analysis/$hostname.txt.old | grep \"disc\" | awk '{print \$5}'`;
chomp $jobsdiscold;
print OUT "Jobs in OPR (disc): $jobsdisc ($jobsdiscold)\n";

$jobsretry = `./sinfo | grep retried | wc | awk '{print \$1}'`;
chomp $jobsretry;
$jobsretryold = `grep OPR /home/server/server2/analysis/$hostname.txt.old | grep \"retry\" | awk '{print \$5}'`;
chomp $jobsretryold;
print OUT "Jobs in OPR (retry): $jobsretry ($jobsretryold)\n";

$jobs = `./sinfo jobs | wc | awk '{print \$1}'`;
chomp $jobs;
$jobsstack = `grep \"Jobs on stack\" /home/server/server2/analysis/$hostname.txt.old | awk '{print \$4}'`;
chomp $jobsstack;
print OUT "Jobs on stack: $jobs ($jobsstack)\n";

$conn = `netstat -n | grep ESTA | wc | awk '{print \$1}'`;
chomp $conn;
print OUT "Current connections: $conn\n";


#######         analysis info & HD status          ##############
foreach $name (@dirs){
  @logsfiles = `ls /home/server/server2/analysis/$name/LOGS/*log*`;
  $numlogsleft = 0;
  $addtosum = 0;
  $sumundone = 0;
  foreach $xlog (@logsfiles){
    chomp $xlog;
    @logsnames = split(/\./,$xlog);
    $newxlog = "$name.log."."@logsnames[2]";
    $donelog = "/home/server/server2/analysis/$name/DONE/$newxlog."."done";
    if(!(-e $donelog)){
      $numlogsleft++;
      $addtosum = `wc $xlog | awk '{print \$1}'`;     
      $sumundone+=$addtosum;
      print STDOUT "$donelog	$addtosum	$sumundone\n";
    }
  }
  print OUT "Number of $name logs not analyzed: $numlogsleft ($sumundone WU's)\n";
}

if(-e "/home/server/server2/analysis/running_flag"){ print OUT "Analysis status: running_flag\n"; }
if(-e "/home/server/server2/analysis/job_finished"){ print OUT "Analysis status: job_finished\n"; }
$anal = `ps awux | grep \"server\" | grep \"input_records_\" | grep \"log\" | awk '{print \$12}'`;
for($anal) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
@analjob = split(/ /,$anal);
print OUT "Analysis scripts running: $analjob[0]\n";

$ftp = `ps awux | grep ftp | wc | awk '{print \$1}'`; 
print STDOUT "$ftp\n";
chomp $ftp;
#for($ftp) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
$ftp-=2;
print OUT "backup status: $ftp ftp in progress\n";

print OUT "\nCurrent HD status:\n";
$hd = `df -P`;
print OUT "$hd\n\n";
chdir("analysis");


#######		Look for bad IP's Error.log has grown	#########
# first backup & sort the current Error.log for working #
`grep "Core error" $error_file | sort > $error_file_bu`;
if(-e $error_ips){ `cp $error_ips $error_ips_old`; }

# open the output file #
open(BU,"<$error_file_bu") || die "\n\tError reading from backup error file\n\n";
open(IP,">tempIPs") || die "\n\tError writing to temp IPs file\n\n";
open(NEW,">$error_file_ur") || die "\n\tError writing to new error file\n\n";

$last_IP = "0.0.0.0";
$isitbad = 0;
while(defined($line=<BU>)){
  chomp $line;
  $whole = $line;
  for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
  @input = split(/ /,$line);
  $test = @input[1];
 
  # ignore non-error info lines #
  if($test eq "Client"){
    $IP = @input[2];
    if($IP == $last_IP){
      $count{$IP}++;
    }else{
      $count{$IP}=1;
      if($count{$last_IP} > $max_errors){ print IP "HOSTS_DENY $last_IP\n"; }
    }

    # has that WU been done by another client? #
    $window = @input[9];
    chomp $window;
    for($window){ s/\(//; s/\)//; }
    @job = split(/,/,$window);
    $proj = @job[0];
    $run = @job[1];
    $frame = @job[2];
    $clone = @job[3];

    # if test edr exists, that WU was done by another #
    $testedr = "$data_dir/PROJ$proj/RUN$run/CLONE$clone/frame$frame.edr";
    if(-e $error_ips){ 
      $isitbad = `grep -x \"HOSTS_DENY $IP\" $error_ips | wc | awk '{print \$1}'`; 
      chomp $isitbad; 
    }
    if((!(-e $testedr))&&($isitbad == 0)){      print NEW "$whole\n";     }
    $last_IP = $IP;  
  }elsif($test eq "FAULTYWU_RETRY_MAX"){
    print NEW "$whole\n"; 
  }
}
close(NEW);
close(BU);
close(IP);

if($rmips==1){
  # setup the LAST_ASSIGN IPs #
  `less tempIPs >> $error_ips; rm tempIPs`;
  `less $error_ips | sort | uniq > tempIPs`; 
  `mv tempIPs $error_ips`;

  # check for differences in Error.ips and log result #
  $wc11 = `wc $error_ips | awk '{print \$1}'`; chomp $wc11;
  $wc22 = `wc $error_ips_old | awk '{print \$1}'`; chomp $wc22;
  open(TEMP,">difftemp") || die "\n\tError opening temp file\n\n";
  if($wc11 == $wc22){
    print TEMP "No additional IP's added to blacklist - $date\n\n";
  }else{
    $diff = $wc11 - $wc22;
    print TEMP "$diff additional IP's added to blacklist - $date\n\n";

    # if new IP's are blacklisted, update project.conf #
    open(PRO,"<../project.conf") || die "\n\tError reading from project.conf\n\n";
    open(NEWPRO,">protemp") || die "\n\tError writing to protemp\n\n";
    while(defined($proline=<PRO>)){
      chomp $proline;
      $whole = $proline;
      for($proline) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
      @proin = split(/ /,$proline);
      $protest = @proin[0];
 
      # ignore old banned IP lines #
      if($protest ne "HOSTS_DENY"){
        print NEWPRO "$whole\n";
      }
    }  
    close(NEWPRO);
    close(PRO);
    `less $error_ips >> protemp`;
    `cp ../project.conf ../project.conf.old; mv protemp ../project.conf`; 
  }
  close(TEMP);
  `less difftemp >> $restart; rm difftemp`;
}


############### 	get num WU attempted & errors per project    #############
$num_fin_tot = 0;
$errors=0;
foreach $x (@projs){
  $dbtest=0;
  $num_fin_init=0;
  $db{$x}=0;
  my $db = DBI->connect("DBI:mysql:project$x:$server",server,"") or next;
  my $first = $db->prepare("select count(*) from frames");
  $first->execute;
  my $getit = $first->fetchrow_array;
  $first->finish;
  $db->disconnect;
  $num_fin{$x} = $getit/$framesperwu{$x};
  $num_fin_tot+=$num_fin{$x};
  $err{$x} = `grep Client $error_file_ur | grep "($x" | wc | awk '{print \$1}'`;
  $errors+=$err{$x}; 
}


########## 	 get stats on all errors & banned IPs		#########
print OUT "Server Project Status\n";
$numdone = $num_fin_tot;
print OUT "$numdone\tWU's completed (in DB)\n";
print OUT "$errors\tunresolved core errors reported\n";

if(($numdone>0)&&($errors>0)){
  $percent = 100*($errors/($numdone+$errors));
  printf OUT "%2.2f\%\tunresolved job returns\n",$percent;
}

if(-e Error.ips){ $badips = `wc Error.ips | awk '{print \$1}'`; }else{ $badips =0; }
chomp $badips;
$banned = `grep HOSTS_DENY log | wc | awk '{print \$1}'`;
chomp $banned;
$new_ips = $badips - $banned;
print OUT "$new_ips\tbanned IPs since last restart\n\n";


#########	get errors by project number	########
print OUT "Project\t\%error\tcomp\tunres\tassigned\ttried\tunanalyzed\t    description\t         totaltime(ns)\tdiskusage\n";
foreach $x (@projs){
  $num_err = `grep "($x" $error_file_ur | wc | awk '{print \$1}'`;
  chdir ("/home/server/server2/");
  $num_ass = `./sinfo | grep \"\($x\,\" | grep wait | wc | awk '{print \$1}'`;
  chomp $num_ass;
  chdir ("/home/server/server2/analysis/");
  chomp $num_err;
  $num_comp = $num_fin{$x};
  if($num_comp>0){
    $percent = 100*($num_err/($num_comp+$num_err));
    $num_back = "N/A";
    $num_tried = "N/A";
    $totaltime = ($num_comp * $mdtimestep{$x} * $maxiter{$x})/1000000;
    `du -ch /home/server/server2/data/PROJ$x/ > dusage`;
    @diskusage = `tail -1 dusage`;
    `rm dusage`;
    for(@diskusage){  s/^\s+//; s/\s+$//; s/\s+/ /g; }
    $dusage = @diskusage[0];
  }else{
    $totaltime = 0;
    $percent = "N/A";
    $num_back = `grep \"$statscredit{$x}\" */LOGS/* | grep \"\($x\,\" | wc | awk '{print \$1}'`;
print STDOUT "$num_back    statscredit = $statscredit{$x}\n\n";
    $num_back-=$num_comp;
    $num_tried = `grep \"\($x\,\" */LOGS/* | wc | awk '{print \$1}'`;
    chomp $num_comp;
    chomp $num_tried;
  }
  printf OUT "$x\t%2.2f\t%d\t%d\t%d\t\t%d\t%d\t\t%20s\t%10d\t%10s\n",$percent,$num_comp,$num_err,$num_ass,$num_tried,$num_back,$description{$x},$totaltime,$dusage;
}

print OUT "\n";

#########	  get the RAID status		#########
`omreport storage pdisk controller=0 > raid.txt`;
print OUT "\nRAID status from omreport\n";

open(RAID,"<raid.txt") || die "Error: can't get vital info from raid.txt\n\n";
$raidnum = 0;
@raidid = '';
@raidstat = '';
@raidstate = '';
@raidfail = '';
while(defined($line = <RAID>)) {
    chomp $line;
    for($line) {  s/^\s+//; s/\s+$//; s/\s+/ /g; }
    @linein = split(/ /,$line);
    if(@linein[0] eq 'ID'){ @raidid[$raidnum] = @linein[2]; }
    if(@linein[0] eq 'Status'){ @raidstat[$raidnum] = @linein[2]; }
    if(@linein[0] eq 'State'){ @raidstate[$raidnum] = @linein[2]; }
    if(@linein[0] eq 'Failure'){ @raidfail[$raidnum] = @linein[3]; }
    if(@linein[0] eq 'SAS'){ $raidnum++; }
}
print OUT "Drive\tStatus\tState\tPredictFailure\n";
for($ra=0;$ra<$raidnum;$ra++){
	print OUT "@raidid[$ra]\t@raidstat[$ra]\t@raidstate[$ra]\t@raidfail[$ra]\n";
}
`rm raid.txt`;


#########	cleanup the dirs & exit		#########
if($cleanup==1){
  `rm tempIPs $error_file_bu $error_file_ur $error_ips_old serverstat.html`;
}
$date = `date`;  chomp $date;
print OUT "\nerrorinfo.pl completed on $date\n";
close(OUT);
`scp folding2.txt banana.cnsm.csulb.edu:/srv/www/banana/`;
exit();
