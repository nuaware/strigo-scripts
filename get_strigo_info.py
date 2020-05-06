#!/usr/bin/env python3

import os, sys
import requests, json
import urllib.request

def die(msg):
    print("die: " + msg)
    sys.exit(1)

VERBOSE=os.getenv('VERBOSE', None)

MISSING_ENV_VARS=[]

ORG_ID=os.getenv('ORG_ID')
API_KEY=os.getenv('API_KEY')

OWNER_ID_OR_EMAIL=os.getenv('OWNER_ID_OR_EMAIL')

PRIVATE_IP=os.getenv('PRIVATE_IP')
PUBLIC_IP=os.getenv('PUBLIC_IP')

if ORG_ID            == None: MISSING_ENV_VARS.append('ORG_ID')
if API_KEY           == None: MISSING_ENV_VARS.append('API_KEY')
if OWNER_ID_OR_EMAIL == None: MISSING_ENV_VARS.append('OWNER_ID_OR_EMAIL')
if PRIVATE_IP        == None: MISSING_ENV_VARS.append('PRIVATE_IP')
if PUBLIC_IP         == None: MISSING_ENV_VARS.append('PUBLIC_IP')

if len(MISSING_ENV_VARS) > 0:
    die("Missing env var definitions: " + " ".join(MISSING_ENV_VARS))

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
    if VERBOSE: print(f"workspaces={workspaces}")

    myWorkspace=None

    for ws in workspaces['data']:
        workspaceId=ws['id']
        workspacePrivateIps=[]
        workspacePublicIps=[]
        if VERBOSE: print(f"workspaceId={workspaceId}")

        url = f"https://app.strigo.io/api/v1/events/{eventId}/workspaces/{workspaceId}/resources"
        workspace = requests.get(url, headers=headers).json()
        if VERBOSE: print(f"workspace={workspace}")
        for lab_inst in workspace['data']:
            lab_instance_id=lab_inst['id']
            private_ip=lab_inst['private_ip']
            public_ip=lab_inst['public_ip']
            if VERBOSE: print(f"lab_id={lab_instance_id} private_ip=${private_ip} public_ip={public_ip}")

            workspacePrivateIps.append(private_ip)
            workspacePublicIps.append(public_ip)

            if private_ip == PRIVATE_IP:
                myWorkspace=workspaceId
                if VERBOSE:
                    print(f"FOUND my workspace: ID={workspaceId}")
                    print(f"-- lab_instance_id={lab_instance_id}")
                    print(f"-- private_ip={private_ip}")
                    print(f"-- public_ip={public_ip}")

        if myWorkspace:
            return ( workspaceId, workspacePrivateIps, workspacePublicIps )

    # PRIVATE_IP=os.getenv('PRIVATE_IP')
    #return res.json()
    return ( None, None, None )

def getNumberOfNodes( eventId ):
    ( workspaceId, workspacePrivateIps, workspacePublicIps ) = \
        getMyWorkspaceIPs( eventId )
    return len(workspacePrivateIps)

def getMyNodeIndex( eventId ):
    ( workspaceId, workspacePrivateIps, workspacePublicIps ) = \
        getMyWorkspaceIPs( eventId )

    for idx in range(len(workspacePrivateIps)):
        private_ip = workspacePrivateIps[idx]
        if private_ip == PRIVATE_IP:
            return idx

    return -1

# Shift off 'prog' argument:
prog=sys.argv[0]; sys.argv=sys.argv[1:]

while len(sys.argv) > 0:
    arg=sys.argv[0]; sys.argv=sys.argv[1:]

    if arg == '-v':
        VERBOSE=True

    if arg == '-o':
        arg=sys.argv[0]; sys.argv=sys.argv[1:]
        OWNER_ID_OR_EMAIL=arg

    if arg == '-e':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        #print(f"eventId={eventId}")
        print(eventId)

    if arg == '-W':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        if VERBOSE: print(f"eventId={eventId}")
        workspaces = getEventWorkspaces( eventId )
        if VERBOSE: print(f"workspaces={workspaces}")
        for w in workspaces['data']:
            print(w['id'])

    if arg == '-w':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        if VERBOSE: print(f"eventId={eventId}")
        ( workspaceId, workspacePrivateIps, workspacePublicIps ) = \
            getMyWorkspaceIPs( eventId )
        print(workspaceId)

    if arg == '-ips':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        if VERBOSE: print(f"eventId={eventId}")
        ( workspaceId, workspacePrivateIps, workspacePublicIps ) = \
            getMyWorkspaceIPs( eventId )

        if len(sys.argv) > 0:
            idx=int(sys.argv[0])
            print(f"{workspacePrivateIps[idx]},{workspacePublicIps[idx]}")
            sys.exit(0)

        print( workspacePrivateIps, workspacePublicIps )
        sys.exit(0)

    if arg == '-idx':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        if VERBOSE: print(f"eventId={eventId}")
        idx = getMyNodeIndex( eventId )
        print(idx)

    if arg == '-nodes':
        eventId = getMyEventId( OWNER_ID_OR_EMAIL, status='live' )
        if VERBOSE: print(f"eventId={eventId}")
        nodes = getNumberOfNodes( eventId )
        print(nodes)
