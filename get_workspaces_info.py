#!/usr/bin/env python3

import os, sys
import requests, json
import urllib.request

VERBOSE=os.getenv('VERBOSE', None)

ORG_ID=os.getenv('ORG_ID')
API_KEY=os.getenv('API_KEY')

OWNER_ID_OR_EMAIL=os.getenv('OWNER_ID_OR_EMAIL')

PRIVATE_IP=os.getenv('PRIVATE_IP')
PUBLIC_IP=os.getenv('PUBLIC_IP')

headers = {
    'Authorization': "Bearer " + ORG_ID + ":" + API_KEY,
    'Accept': 'application/json',
    'Content-Type': 'application/json'
}

if VERBOSE != None:
    print(f"headers: {headers}")

def response(url):
    with urllib.request.urlopen(url, headers=headers) as response:
        return response.read()

    res = response(url)
    ret = json.loads(res)
    if VERBOSE:
        print(f"get({url}) ==> {ret}")
    return ret

def getEvents():
    url = "https://app.strigo.io/api/v1/events"
    res = requests.get(url, headers=headers)
    #print(type(res))
    #print(res)
    return res.json()

def getMyEventId( owner_id_or_email, status='live' ):
    events = getEvents()
    field = 'id'

    for ev in events['data']:
        #print(ev)
        if ev['status'] == status and \
                (ev['owner']['email'] == owner_id_or_email or \
                 ev['owner']['id'] == owner_id_or_email):
            if field == '*':
                if VERBOSE: print(f"event={json.dumps(ev,  indent=2, sort_keys=True)}")
            else:
                if VERBOSE: print(f"event[{field}]={ev[field]}")
                return ev[field]

def getEventWorkspaces( eventId ):
    url="https://app.strigo.io/api/v1/events/" + eventId + "/workspaces" 
    res = requests.get(url, headers=headers)
    return res.json()

eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )

print(f"eventId={eventId}")

workspaces = getEventWorkspaces( eventId )

print(f"workspaces={workspaces}")


'''
for ev in json.load(sys.stdin)['data']:
    if ev['status'] == status and ev['owner']['email'] == owner_id_or_email:
        if field == '*':
            print(json.dumps(ev,  indent=2, sort_keys=True))
        else:
            print(ev[field])
'''



