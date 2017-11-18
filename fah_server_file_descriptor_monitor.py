# fah_server_file_descriptor_monitor.py
#
# Follow the amount of file descriptors used by the F@H server.

import datetime
from subprocess import Popen, check_output, PIPE
from error_reporting_bot import post_message


def get_pid(name):
    return check_output(["pidof", name])


def get_file_descriptor_count(process_pid):
    ls_process = Popen(
        ['ls', '-1q', '/proc/{}/fd'.format(process_pid)], stdout=PIPE)
    wc_out, _ = Popen(['wc', '-l'], stdin=ls_process.stdout).communicate()
    return wc_out.rstrip()


def main():
    fah_work_pid = get_pid('fah-work').rstrip()
    assert fah_work_pid, post_message('[ERROR] WS on folding1 has shutdown!')
    current_date_time = str(datetime.datetime.now()).replace(' ', '-')
    fah_work_file_descriptor_count = get_file_descriptor_count(fah_work_pid)
    with open('/home/server/server2/fah-work-fd-count.log', 'a') as fd_log_file:
        fd_log_file.write(
            '{0:5}{1}'.format(fah_work_file_descriptor_count, current_date_time))

if __name__ == '__main__':
    main()
