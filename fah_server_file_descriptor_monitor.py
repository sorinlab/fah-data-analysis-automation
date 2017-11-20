# fah_server_file_descriptor_monitor.py
#
# Follow the amount of file descriptors used by the F@H server.

import datetime
import sys
from subprocess import check_output, CalledProcessError
from error_reporting_bot import post_message


def get_pid(name):
    return check_output(["pidof", name])


def get_file_descriptor_count(process_pid):
    wc_out = check_output('ls -1q /proc/{}/fd | wc -l'.format(process_pid), shell=True)
    return wc_out.rstrip()


def main():
    try:
        fah_work_pid = get_pid('fah-work')
    except CalledProcessError:
        post_message('[ERROR] WS on folding1 has shutdown!')
        sys.exit()
    fah_work_pid = fah_work_pid.rstrip()
    current_date_time = str(datetime.datetime.now()).replace(' ', '-')
    fah_work_file_descriptor_count = get_file_descriptor_count(fah_work_pid)
    with open('/home/server/server2/fah-work-fd-count.log', 'a') as fd_log_file:
        fd_log_file.write(
            '{0:5}{1}\n'.format(fah_work_file_descriptor_count, current_date_time))

if __name__ == '__main__':
    main()
