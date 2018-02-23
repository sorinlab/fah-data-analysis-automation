#!/usr/bin/env python
''' The F@H Analysis-Work Scouter'''


import logging
import json
import os
import sys
from collections import deque
from config import SCOUT_CONFIGURATION as SC
from error_reporting_bot import post_message

# Sample configuration ###
# SCOUT_CONFIGURATION = {
#     'projects': {
# Project Set ("Codename")
#         'Test': {
# Project Directories
#             'directories': {
# Boolean to determine if a Project is scoutable
# If true, scout the project for work
#                 '/.../PROJ8299': True
#             },
# Boolean to determine if a Project Set is scoutable
# If true, iterate over 'directories'
#             'scoutable': True
#         }
#     },
# Path to lock file
# If lock file exists do not execute scout
#     'lock': '/.../lock.txt',
# Path to queue
#     'queue': '/.../queue.txt',
# Path to work completed log
# If a to-be-analyzed frame exists in work_completed do not queue
#     'work_completed': '/.../done.txt',
# Path to failed WU log
# If a to-be-analyzed frame exists in failed_wu do not queue
#      'failed_wu': '/home/server/server2/analysis/failed_WU.txt',
# Path to file that logs events that occur during normal operation
#     'log' : '/.../scout.log',
# Path to file that logs errors regarding a particular runtime event
#     'error_log' : '/.../scout-error.log',
# Webhook (Slack) for the scout to POST error messages
#     'webhook' : 'https://<url>.<goes>.<here>/...'
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
try:
    LOG = setup_logger('log', SC['log'])
    ERROR_LOG = setup_logger('error_log', SC['error_log'])
except IOError as err:
    post_message(
        '[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to setup loggers.'.format(err.errno, err.strerror))
    sys.exit(1)

# Check fo the existence of a lock file
# If present exit, otherwise set lock and continue
LOCK = SC['lock']
if os.path.isfile(LOCK):
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
        post_message(
            '[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to set lock={}.'.format(err.errno, err.strerror, LOCK))
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
    post_message(
        '[ERROR] in scout.py. The queue file {} does not exist.'.format(QUEUE))
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
    post_message(
        '[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to open queue={}.'.format(err.errno, err.strerror, QUEUE))
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
    post_message(
        '[ERROR] in scout.py. The done (work finished) file {} does not exist.'.format(WORK_COMPLETED))
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
    post_message('[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to open work_completed={}.'.format(
        err.errno, err.strerror, WORK_COMPLETED))
    os.unlink(LOCK)
    sys.exit(1)
WORK_COMPLETED_SET = set()
for line in WORK_COMPLETED_LINES:
    (_, xtc_path) = line.split()
    WORK_COMPLETED_SET.add(xtc_path)
# Deallocate list of finished job entries from memory
del WORK_COMPLETED_LINES

# Make a dictionary of all the failed WU's
# This will be used to prevent reentering failed WU's into queue
FAILED_WU = SC['failed_wu']
if os.path.isfile(FAILED_WU):
    LOG.info(': Opening failed_wu file and creating dictionary.')
else:
    ERROR_LOG.info(
        ': [ERROR] The failed_wu file %s does not exist. Check the configuration for errors regarding the \'failed_wu\' setting.', FAILED_WU)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    post_message(
        '[ERROR] in scout.py. The failed_wu file {} does not exist.'.format(FAILED_WU))
    os.unlink(LOCK)
    sys.exit(1)
try:
    with open(FAILED_WU, mode='r') as failed_wu_log:
        FAILED_WU_LINES = failed_wu_log.readlines()
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to open failed_wu=%s. Check the configuration for errors regarding the \'failed_wu\' setting.', err.errno, err.strerror, FAILED_WU)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
    post_message('[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to open failed_wu={}.'.format(
        err.errno, err.strerror, FAILED_WU))
    os.unlink(LOCK)
    sys.exit(1)
FAILED_WU_SET = set()
for line in FAILED_WU_LINES:
    (_, xtc_path) = line.split()
    FAILED_WU_SET.add(xtc_path)
# Deallocate list of failed job entries from memory
del FAILED_WU_LINES

# Take union of work completed, queue, and failed to make a set of "ignorables"
CONTINUE_SET = WORK_QUEUED_SET.union(WORK_COMPLETED_SET).union(FAILED_WU_SET)

# Deallocate work completed/queued sets
del WORK_COMPLETED_SET, WORK_QUEUED_SET, FAILED_WU_SET

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
ENQUEUE = deque()
for project_name, directory in WORK:
    directory_walk = os.walk(directory, topdown=True)
    for root, _, files in directory_walk:
        for f in files:
            if f.endswith(".xtc"):
                xtc_path = os.path.abspath(os.path.join(root, f))
                # Do not include WU's that are past the CLONE<#> directory
                if 'CLONE' not in xtc_path.split('/')[-2]:
                    continue
                # Skip WU's that are either queued or finished, otherwise mark
                # them
                if xtc_path in CONTINUE_SET:
                    continue
                else:
                    ENQUEUE.appendleft(
                        '{:<10}\t{:<}'.format(project_name, xtc_path))

# Write enqueue list entries to the queue
LOG.info(': Writing %d entries to queue.', len(ENQUEUE))
try:
    with open(QUEUE, mode='a') as queue_file:
        for item in ENQUEUE:
            queue_file.write('{}\n'.format(item))
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to open queue=%s. Check the configuration for errors regarding the \'queue\' setting.', err.errno, err.strerror, QUEUE)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    os.unlink(LOCK)
    post_message(
        '[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to open queue={}.'.format(err.errno, err.strerror, QUEUE))
    sys.exit(1)

LOG.info(': Sorting the queue.')
try:
    with open(QUEUE, mode='r') as queue_file:
        WQL = list(set(queue_file.readlines()))
    WQL.sort(key=lambda x: int(x.split()[1].split('/')[-1].split('.')[0][5:]))
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to open queue=%s. This error is unexpected and could mean that the queue was deleted intermittently.', err.errno, err.strerror, QUEUE)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
    os.unlink(LOCK)
    post_message(
        '[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to open queue={}. This error is unexpected and could mean that the queue was deleted intermittently.'.format(err.errno, err.strerror, QUEUE))
    sys.exit(1)
try:
    with open(QUEUE, mode='w') as queue_file:
        for x in xrange(len(WQL)):
            queue_file.write(WQL[x])
    LOG.info(': Finished sorting the queue.')
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to open queue=%s. This error is unexpected and could mean that the queue was deleted intermittently.', err.errno, err.strerror, QUEUE)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
    post_message(
        '[ERROR] in scout.py. I/O Error({}): {}. Occurred when attempting to open queue={}. This error is unexpected and could mean that the queue was deleted intermittently.'.format(err.errno, err.strerror, QUEUE))
    os.unlink(LOCK)
    sys.exit(1)

# Release lock and exit
os.unlink(LOCK)
LOG.info(': Scouting finished and lock unset.')
