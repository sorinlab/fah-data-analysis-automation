'''Configuration properties for scout.py'''


SCOUT_CONFIGURATION = {
    'projects': {
        # Project Set ("Codename")
        'Test': {
            # Project Directories
            'directories': {
                # Boolean to determine if a Project is scoutable
                # If true, scout the project for work
                '/.../.../.../PROJ<#>': True
            },
            # Boolean to determine if a Project Set is scoutable
            # If true, iterate over 'directories'
            'scoutable': True
        }
    },
    # Path to lock file
    # If lock file exists do not execute scout
    'lock': '/.../.../.../lock.txt',
    # Path to queue
    'queue': '/.../.../.../queue.txt',
    # Path to work completed log
    # If a to-be-analyzed frame exists in work_completed do not queue
    'work_completed': '/.../.../.../done.txt',
    # Path to file that logs events that occur during normal operation
    'log' : '/.../.../.../scout.log',
    # Path to file that logs errors regarding a particular runtime event
    'error_log' : '/.../.../.../scout-error.log'
}
