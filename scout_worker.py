#!/usr/bin/env python
''' The F@H Analysis-Work Scout Worker'''


import argparse
import logging
import os
import pickle
import sys
from collections import deque
from config import SCOUT_CONFIGURATION as SC

ARGUMENT_PARSER = argparse.ArgumentParser()
ARGUMENT_PARSER.add_argument('codename')
ARGUMENT_PARSER.add_argument('directory')
ARGUMENT_PARSER.add_argument('pickle')
ARGS = ARGUMENT_PARSER.parse_args()
PROJECT_NAME = ARGS.codename
DIRECTORY = ARGS.directory
PICKLE_PATH = ARGS.pickle

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

# Load object from pickle
try:
    with open(PICKLE_PATH, mode='rb') as pkl:
        CONTINUE_SET = pickle.load(pkl)
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to load pickle=%s. Check the scout_wrapper.py script for errors regarding the \'PICKLE_PATH\' setting.', err.errno, err.strerror, PICKLE_PATH)
    LOG.warning(
        ': [WARNING] The scout is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    sys.exit(1)

# Scout data directories for unanalyzed WU's
# and make a queue out of them
# This queue will be used to write into the queue file,
# therefore marking them for analysis
ENQUEUE = deque()
DIRECTORY_WALK = os.walk(DIRECTORY, topdown=True)
for root, _, files in DIRECTORY_WALK:
    for f in files:
        if f.endswith(".xtc"):
            xtc_path = os.path.abspath(os.path.join(root, f))
            # Skip WU's that are either queued or finished, otherwise mark
            # them
            if xtc_path in CONTINUE_SET:
                continue
            else:
                ENQUEUE.appendleft('{:<10}\t{:<}'.format(PROJECT_NAME, xtc_path))

# Write enqueue list entries to the queue
QUEUE = SC['queue']
LOCK = '{}/worker_lock.txt'.format(os.path.dirname(QUEUE))
# Check for the existance of a worker lock
while os.path.isfile(LOCK):
    continue
try:
    open(LOCK, mode='a').close()
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to set worker lock=%s. Check for errors in the scout_worker.py script on variable \'LOCK\'.', err.errno, err.strerror, LOCK)
    LOG.warning(
        ': [WARNING] A scout worker is terminating due to a critical error. Please see %s for more information. Unsetting worker lock and exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)
LOG.info(': Writing %d entries to queue.', len(ENQUEUE))
try:
    with open(QUEUE, mode='a') as queue_file:
        for item in ENQUEUE:
            queue_file.write('{}\n'.format(item))
except IOError as err:
    ERROR_LOG.info(
        ': [ERROR] I/O Error(%d): %s. Occurred when attempting to open queue=%s. Check the configuration for errors regarding the \'queue\' setting.', err.errno, err.strerror, QUEUE)
    LOG.warning(
        ': [WARNING] A scout worker is terminating due to a critical error. Please see %s for more information. Unsetting lock and exiting...', SC['error_log'])
    os.unlink(LOCK)
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
        ': [WARNING] A scout worker is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
    os.unlink(LOCK)
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
        ': [WARNING] A scout worker is terminating due to a critical error. Please see %s for more information. Exiting...', SC['error_log'])
    os.unlink(LOCK)
    sys.exit(1)

# Release lock and exit
os.unlink(LOCK)
LOG.info(': Worker finished and its lock unset.')
