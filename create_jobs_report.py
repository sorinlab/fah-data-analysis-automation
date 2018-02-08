#!/usr/bin/env python3

'''Create report of jobs on F@H server'''

import json
import requests
import sys

JSON_RESPONSE = requests.get(
    url='http://folding2.cnsm.csulb.edu:8080/api/jobs?order_by=Project%2CRun%2CClone&limit=8000&offset=0')
JSON_DATA = JSON_RESPONSE.json()
JSON_DATA = [{'project': job['project'], 'run': job['run'],
              'clone': job['clone'], 'state': job['state']} for job in JSON_DATA]
ASSIGNED_JOBS = [job for job in JSON_DATA if 'ASSIGNED' in job['state']]
READY_JOBS = [job for job in JSON_DATA if 'READY' in job['state']]
FAILED_JOBS = [job for job in JSON_DATA if 'FAILED' in job['state']]
ASSIGNED_JOBS.sort(key=lambda x: (x['project'], x['run'], x['clone']))
READY_JOBS.sort(key=lambda x: (x['project'], x['run'], x['clone']))
FAILED_JOBS.sort(key=lambda x: (x['project'], x['run'], x['clone']))
FORMAT_STRING = '{:<10}{:<6}{:<8}{:<8}\n'
with open('failed-jobs.log', mode='w') as log_file:
    log_file.write(FORMAT_STRING.format('Project', 'Run', 'Clone', 'State'))
    for job in FAILED_JOBS:
        log_file.write(FORMAT_STRING.format(
            job['project'], job['run'], job['clone'], job['state']))
with open('ready-jobs.log', mode='w') as log_file:
    log_file.write(FORMAT_STRING.format('Project', 'Run', 'Clone', 'State'))
    for job in READY_JOBS:
        log_file.write(FORMAT_STRING.format(
            job['project'], job['run'], job['clone'], job['state']))
with open('assigned-jobs.log', mode='w') as log_file:
    log_file.write(FORMAT_STRING.format('Project', 'Run', 'Clone', 'State'))
    for job in ASSIGNED_JOBS:
        log_file.write(FORMAT_STRING.format(
            job['project'], job['run'], job['clone'], job['state']))
