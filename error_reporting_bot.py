import requests
import simplejson as json
from config import SCOUT_CONFIGURATION as SC

URL = SC['webhook']
HEADERS = {'Content-type': 'application/json'}


def post_message(message):
    data = {'text': message}
    try:
        r = requests.post(URL, data=json.dumps(data), headers=HEADERS)
    except requests.exceptions.ConnectionError:
        pass
