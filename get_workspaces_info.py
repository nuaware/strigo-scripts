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
    url = f"https://app.strigo.io/api/v1/events/{eventId}/workspaces" 
    res = requests.get(url, headers=headers)
    return res.json()

def getMyWorkspaceIPs( eventId ):
    workspaces = getEventWorkspaces( eventId )
    print(f"workspaces={workspaces}")

    myWorkspace=None

    for ws in workspaces['data']:
        workspaceId=ws['id']
        workspacePrivateIps=[]
        workspacePublicIps=[]
        print(f"workspaceId={workspaceId}")

        url = f"https://app.strigo.io/api/v1/events/{eventId}/workspaces/{workspaceId}/resources"
        workspace = requests.get(url, headers=headers).json()
        print(f"workspace={workspace}")
        for lab_inst in workspace['data']:
            lab_instance_id=lab_inst['id']
            private_ip=lab_inst['private_ip']
            public_ip=lab_inst['public_ip']

            workspacePrivateIps.append(private_ip)
            workspacePublicIps.append(public_ip)

            if private_ip == PRIVATE_IP:
                print(f"FOUND my workspace: ID={workspaceId}")
                print(f"-- lab_instance_id={lab_instance_id}")
                print(f"-- private_ip={private_ip}")
                print(f"-- public_ip={public_ip}")
                myWorkspace=workspaceId

        if myWorkspace:
            return ( workspacePrivateIps, workspacePublicIps )

    # PRIVATE_IP=os.getenv('PRIVATE_IP')
    #return res.json()
    return ( None, None )



while len(sys.argv) > 1:
    arg=sys.argv[1]; sys.argv=sys.argv[2:]

    if arg == '-o':
        arg=sys.argv[1]; sys.argv=sys.argv[2:]
        OWNER_ID_OR_EMAIL=arg

    if arg == '-e':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        print(f"eventId={eventId}")

    if arg == '-w':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        print(f"eventId={eventId}")
        workspaces = getEventWorkspaces( eventId )
        print(f"workspaces={workspaces}")

    if arg == '-ips':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        print(f"eventId={eventId}")
        ( workspacePrivateIps, workspacePublicIps ) = \
            getMyWorkspaceIPs( eventId )
        print( workspacePrivateIps, workspacePublicIps )

    if arg == '-idx':
        print(f"idx={idx}")




