# fah_server_error_reporting_bot.py
#
# Follow the F@H log.txt file like tail -f.

import datetime
import subprocess
import sys
import time
from error_reporting_bot import post_message

def follow(thefile):
    thefile.seek(0, 2)
    while True:
        line = thefile.readline()
        if not line:
            time.sleep(0.1)
            continue
        yield line


if __name__ == '__main__':
    logfile = open("/home/server/server2/log.txt", "r")
    loglines = follow(logfile)
    for line in loglines:
        if 'Error from accept() call' in line:
            current_time = str(datetime.datetime.now()).replace(' ', '-')
            netstat_out = subprocess.check_output(['netstat', '-an'])
            with open('/home/server/server2/{}.netstat.out'.format(current_time), 'w') as netstat_file:
                netstat_file.write(netstat_out)
            post_message('[ERROR] Folding1 WS process maxed out file descriptors! Send /home/server/server2/{}.netstat.out to the CSULB IT team!'.format(current_time))
            sys.exit()
