'''Configuration properties for scout.py'''


SCOUT_CONFIGURATION = {
    'projects': {
        # Project Set ("Codename")
        'BCHE': {
            # Project Directories
            'directories': {
                # Boolean to determine if a Project is scoutable
                # If true, scout the project for work
                '/home/server/server2/data/SVR2257269762/PROJ8200': True,
                '/home/server/server2/data/SVR2257269762/PROJ8202': True,
                '/home/server/server2/data/SVR2257269762/PROJ8204': True,
                '/home/server/server2/data/SVR2257269762/PROJ8206': True,
                '/home/server/server2/data/SVR2257269762/PROJ8207': True,
                '/home/server/server2/data/SVR2257269762/PROJ8208': True,
                '/home/server/server2/data/SVR2257269762/PROJ8209': True
            },
            # Boolean to determine if a Project Set is scoutable
            # If true, iterate over 'directories'
            'scoutable': True
        }
    },
    # Path to lock file
    # If lock file exists do not execute scout
    'lock': '/home/server/server2/analysis/lock.txt',
    # Path to queue
    'queue': '/home/server/server2/analysis/queue.txt',
    # Path to work completed log
    # If a to-be-analyzed frame exists in work_completed do not queue
    'work_completed': '/home/server/server2/analysis/done.txt',
    # Path to file that logs events that occur during normal operation
    'log' : '/home/server/server2/analysis/scout-logs/scout.log',
    # Path to file that logs errors regarding a particular runtime event
    'error_log' : '/home/server/server2/analysis/scout-logs/scout-error.log',
    # Slack webhook for the scout to POST error messages
    'webhook' : 'https://<url>.<goes>.<here>/...'
}
