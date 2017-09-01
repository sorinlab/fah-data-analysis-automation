#!/usr/bin/env python
''' The F@H Analysis-Work Scouter'''


import logging
import json
import os
import pickle
import sys
from subprocess import Popen
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

# Check for the existence of a lock file
# If present exit, otherwise set lock and continue
LOCK = SC['lock']
if os.path.isfile(LOCK):
    LOG.warning(': [WARNING] Lock set. Exiting...')
    sys.exit()
else:
    try:
        open(LOCK, mode='a').close()
        LOG.info(': Scout starting with settings:\n%s',
                 json.dumps(SC, indent=4, separators=(',', ': ')))
    except IOError as err:
        ERROR_LOG.info(
            ': [ERROR] I/O Error(%d): %s. Occurred when attempting to set lock=%s. Check the configuration for errors regarding the \'lock\' setting.', err.errno, err.strerror, LOCK)
        LOG.warning(
            ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
        sys.exit(1)

# Make a set of all the currently queued WU's
# This will be used to prevent duplicate queue entries
QUEUE = SC['queue']
if os.path.isfile(QUEUE):
    LOG.info(': Opening queue file and creating dictionary.')
else:
    ERROR_LOG.info(
        ': [ERROR] The queue file %s does not exist. Check the configuration for errors regarding the \'queue\' setting.', QUEUE)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)
try:
    with open(QUEUE, mode='r') as work_queued:
        WORK_QUEUED_LINES = work_queued.readlines()
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to open queue=%s. Check the configuration for errors regarding the \'queue\' setting.', err.errno, err.strerror, QUEUE)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)
WORK_QUEUED_SET = set()
for line in WORK_QUEUED_LINES:
    (_, xtc_path) = line.split()
    WORK_QUEUED_SET.add(xtc_path)
# Deallocate list of queue entries from memory
del WORK_QUEUED_LINES

# Make a dictionary of all the finished WU's
# This will be used to prevent reentering WU's into queue
WORK_COMPLETED = SC['work_completed']
if os.path.isfile(WORK_COMPLETED):
    LOG.info(': Opening done (work finished) file and creating dictionary.')
else:
    ERROR_LOG.info(
        ': [ERROR] The done (work finished) file %s does not exist. Check the configuration for errors regarding the \'work_completed\' setting.', WORK_COMPLETED)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)
try:
    with open(WORK_COMPLETED, mode='r') as work_completed_log:
        WORK_COMPLETED_LINES = work_completed_log.readlines()
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to open work_completed=%s. Check the configuration for errors regarding the \'work_completed\' setting.', err.errno, err.strerror, WORK_COMPLETED)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)
WORK_COMPLETED_SET = set()
for line in WORK_COMPLETED_LINES:
    (_, xtc_path) = line.split()
    WORK_COMPLETED_SET.add(xtc_path)
# Deallocate list of finished job entries from memory
del WORK_COMPLETED_LINES

# Take union of work completed and queue to make a set of "ignorables"
CONTINUE_SET = WORK_QUEUED_SET.union(WORK_COMPLETED_SET)


# Deallocate work completed/queued sets
del WORK_COMPLETED, WORK_QUEUED_SET

PICKLE_PATH = '{}/CONTINUE_SET.pkl'.format(os.path.dirname(LOCK))
if os.path.isfile(PICKLE_PATH):
    os.unlink(PICKLE_PATH)
    with open(PICKLE_PATH, mode='wb') as cs_pickle:
        pickle.dump(CONTINUE_SET, cs_pickle)
else:
    with open(PICKLE_PATH, mode='wb') as cs_pickle:
        pickle.dump(CONTINUE_SET, cs_pickle)

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
                    ERROR_LOG.info(
                        ': [ERROR] The directory %s is a target for scouting but does not exist. Skipping...', directory)

# Scout data directories for unanalyzed WU's
# and make a queue out of them
# This queue will be used to write into the queue file,
# therefore marking them for analysis
PROCESSES = []
for project_name, directory in WORK:
    PROCESSES.append(Popen('python scout_worker.py {} {} {}'.format(project_name, directory, PICKLE_PATH), shell=True))

for process in PROCESSES:
    _, _ = process.communicate()
    return_code = process.returncode
    if return_code > 0:
        LOG.info(': [ERROR] Scout worker terminated unsuccessfully!')
    else:
        LOG.info(': Scout worker terminated successfully.')
LOG.info(': All workers have terminated. Removing lock and exiting...')
os.unlink(LOCK)
