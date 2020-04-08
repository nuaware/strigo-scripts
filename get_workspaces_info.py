#!/usr/bin/env python3

import os, sys
import requests, json
import urllib.request

ORG_ID=os.getenv('ORG_ID')
API_KEY=os.getenv('API_KEY')

headers = {
    'Authorization': "Bearer " + ORG_ID + ":" + API_KEY,
    'Accept': 'application/json',
    'Content-Type': 'application/json'
}

print("headers:")
print(headers)

def response(url):
    with urllib.request.urlopen(url, headers=headers) as response:
        return response.read()

    res = response(url)
    ret = json.loads(res)
    print(ret)
    return ret

def getEvents():
    url = "https://app.strigo.io/api/v1/events"
    res = requests.get(url, headers=headers)
    #print(type(res))
    #print(res)
    return res.json()

owner_email = 'michael.bright@nuaware.com'

def getMyEventId( owner_email, status='live' ):
    events = getEvents()
    field = 'id'

    #print(events)
    #print(json.dumps(events,  indent=2, sort_keys=True))

    #for ev in json.load(events)['data']:
    for ev in events['data']:
        #print(ev)
        if ev['status'] == status and ev['owner']['email'] == owner_email:
            if field == '*':
                print(json.dumps(ev,  indent=2, sort_keys=True))
            else:
                print(ev[field])
                return ev[field]

def getEventWorkspaces( eventId ):
    url="https://app.strigo.io/api/v1/events/" + eventId + "/workspaces" 
    res = requests.get(url, headers=headers)
    return res.json()

eventId = getMyEventId( owner_email, status='live' )

print(eventId)

workspaces = getEventWorkspaces( eventId )

print(workspaces)


'''
for ev in json.load(sys.stdin)['data']:
    if ev['status'] == status and ev['owner']['email'] == owner_email:
        if field == '*':
            print(json.dumps(ev,  indent=2, sort_keys=True))
        else:
            print(ev[field])
'''



