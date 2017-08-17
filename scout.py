#!/usr/bin/env python
''' The F@H Analysis-Work Scouter'''


import logging
import json
import os
import sys
from config import SCOUT_CONFIGURATION as SC

# Sample configuration ###
# SCOUT_CONFIGURATION = {
#     'projects': {
#         # Project Set ("Codename")
#         'Test': {
#             # Project Directories
#             'directories': {
#                 # Boolean to determine if a Project is scoutable
#                 # If true, scout the project for work
#                 '/.../PROJ8299': True
#             },
#             # Boolean to determine if a Project Set is scoutable
#             # If true, iterate over 'directories'
#             'scoutable': True
#         }
#     },
#     # Path to lock file
#     # If lock file exists do not execute scout
#     'lock': '/.../lock.txt',
#     # Path to queue
#     'queue': '/.../queue.txt',
#     # Path to work completed log
#     # If a to-be-analyzed frame exists in work_completed do not queue
#     'work_completed': '/.../done.txt',
#     # Path to file that logs events that occur during normal operation
#     'log' : '/.../scout.log',
#     # Path to file that logs errors regarding a particular runtime event
#     'error_log' : '/.../scout-error.log'
# }

# Set the format of the entries to begin with a timestamp
FORMATTER = logging.Formatter('%(asctime)s %(message)s')


def setup_logger(name, log_file, level=logging.INFO):
    """Function to setup loggers"""

    handler = logging.FileHandler(log_file)
    handler.setFormatter(FORMATTER)

    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.addHandler(handler)

    return logger

# Set up info and error logs
LOG = setup_logger('log', SC['log'])
ERROR_LOG = setup_logger('error_log', SC['error_log'])

# Check fo the existence of a lock file
# If present exit, otherwise set lock and continue
LOCK = SC['lock']
if os.path.isfile(LOCK):
    LOG.warning(': [WARNING] Lock set. Exiting...')
    sys.exit()
else:
    try:
        open(LOCK, mode='a').close()
        LOG.info(': Scout starting with settings:\n%s', json.dumps(SC, indent=4, separators=(',', ': ')))
    except IOError as err:
        ERROR_LOG.info(': [ERROR] I/O Error(%d): %s. Occurred when attempting to set lock=%s. Check the configuration for errors regarding the \'lock\' setting.', err.errno, err.strerror, LOCK)
        LOG.warning(': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
        sys.exit(1)

# Make a dictionary of all the currently queued WU's
# This will be used to prevent duplicate queue entries
QUEUE = SC['queue']
if os.path.isfile(QUEUE):
    LOG.info(': Opening queue file and creating dictionary.')
else:
    ERROR_LOG.info(': [ERROR] The queue file %s does not exist. Check the configuration for errors regarding the \'queue\' setting.', QUEUE)
    LOG.warning(': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)
with open(QUEUE, mode='r') as work_queued:
    WORK_QUEUED_LINES = work_queued.readlines()
WORK_QUEUED_DICT = {}
for line in WORK_QUEUED_LINES:
    (project_name, xtc_path) = line.split()
    if project_name in WORK_QUEUED_DICT:
        WORK_QUEUED_DICT[project_name].append(xtc_path)
    else:
        WORK_QUEUED_DICT[project_name] = [xtc_path]
# Deallocate list of queue entries from memory
del WORK_QUEUED_LINES

# Make a dictionary of all the finished WU's
# This will be used to prevent reentering WU's into queue
WORK_COMPLETED = SC['work_completed']
if os.path.isfile(WORK_COMPLETED):
    LOG.info(': Opening done (work finished) file and creating dictionary.')
else:
    ERROR_LOG.info(': [ERROR] The done (work finished) file %s does not exist. Check the configuration for errors regarding the \'work_completed\' setting.', WORK_COMPLETED)
    LOG.warning(': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)
with open(WORK_COMPLETED, mode='r') as work_completed_log:
    WORK_COMPLETED_LINES = work_completed_log.readlines()
WORK_COMPLETED_DICT = {}
for line in WORK_COMPLETED_LINES:
    (project_name, xtc_path) = line.split()
    if project_name in WORK_COMPLETED_DICT:
        WORK_COMPLETED_DICT[project_name].append(xtc_path)
    else:
        WORK_COMPLETED_DICT[project_name] = [xtc_path]
# Deallocate list of finished job entries from memory
del WORK_COMPLETED_LINES

# Based off the scout configuration,
# determine which data to scout and
# and make a list out of it
PROJECTS = SC['projects']
WORK = []
for project_name, meta_data in PROJECTS.items():
    scoutable = meta_data['scoutable']
    if scoutable:
        directories = meta_data['directories']
        for directory, switch in directories.items():
            if switch:
                if os.path.isdir(directory):
                    WORK.append((project_name, directory))
                    LOG.info(': Directory=%s marked for scouting.', directory)
                else:
                    ERROR_LOG.info(': [ERROR] The directory %s is a target for scouting but does not exist. Skipping...', directory)

# Scout data directories for unanalyzed WU's
# and make a list out of them
# This list will be used to write into the queue file,
# therefore marking them for analysis
ENQUEUE_LIST = []
for project_name, directory in WORK:
    # Determine if the project name has entries
    # in the work finished file
    # If so, obtain the list of completed WU's for that project
    if project_name in WORK_COMPLETED_DICT:
        project_completed_xtcs = WORK_COMPLETED_DICT[project_name]
    else:
        project_completed_xtcs = []
    # Determine if the project name has entires
    # in the queue file
    # If so, obtain the list of WU's queued for that project
    if project_name in WORK_QUEUED_DICT:
        project_queued_xtcs = WORK_QUEUED_DICT[project_name]
    else:
        project_queued_xtcs = []
    # Perform scouting and marking WU's for analysis
    directory_walk = os.walk(directory)
    for root, _, files in directory_walk:
        for f in files:
            if f.endswith(".xtc"):
                xtc_path = os.path.abspath(os.path.join(root, f))
                # Skip WU's that are either queued or finished, otherwise mark them
                if xtc_path in project_completed_xtcs:
                    pass
                else:
                    if xtc_path in project_queued_xtcs:
                        pass
                    else:
                        ENQUEUE_LIST.append(
                            '{:<10}\t{:<}'.format(project_name, xtc_path))

# Write enqueue list entries to the queue
LOG.info(': Writing %d entries to queue.', len(ENQUEUE_LIST))
with open(QUEUE, mode='a') as queue_file:
    ENQUEUE_LIST.sort(key=lambda x: int(x.split()[1].split('/')[-1].split('.')[0][5:]))
    for x in xrange(len(ENQUEUE_LIST)):
        queue_file.write('{}\n'.format(ENQUEUE_LIST[x]))

# Release lock and exit
os.unlink(LOCK)
LOG.info(': Scouting finished and lock unset.')
