#!/bin/csh

set dir = "/home/server/server2/analysis/ACHE"
cd /home/server/server2/analysis/ACHE/LOGS

foreach x (ACHE.log.*)
	echo $x
	if ((!(-e $dir/DONE/$x.done))&&(!(-e /home/server/server2/analysis/running_flag))) then
		cp $x $dir
		cd $dir 
		nice ./input_records_XCHE.pl $x >& /dev/null
	endif
	cd /home/server/server2/analysis/ACHE/LOGS
end
