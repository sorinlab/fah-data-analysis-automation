# fah_server_monitor.py
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
        if 'shutdown' in line:
            current_time = str(datetime.datetime.now())
            post_message('[ERROR] Folding1 WS shutdown!'.format(current_time))
            sys.exit()
