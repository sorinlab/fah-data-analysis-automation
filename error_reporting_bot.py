import requests
import simplejson as json
from config import SCOUT_CONFIGURATION as SC

URL = SC['webhook']
HEADERS = {'Content-type': 'application/json'}

def post_message(message):
    data = {'text': message}
    r = requests.post(url, data=json.dumps(data), headers=headers)

