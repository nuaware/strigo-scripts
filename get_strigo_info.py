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

def getEvents(status=None):
    url = "https://app.strigo.io/api/v1/events"
    res = requests.get(url, headers=headers)
    events = res.json()
    #print(f"Filtering on events={events}")
    if status:
        if VERBOSE: print(f"Filtering on event status='{status}'")
        filteredEvents = {}
        for field in events:
            if field != 'data':
                filteredEvents[field] = events[field]
        filteredEvents['data']=[]

        for event in events['data']:
            if event['status'] == status:
                #print("MATCHED")
                filteredEvents['data'].append(event)
            #else:
                #print("Skipping status='{event['status']}'")
        return filteredEvents

    #print(type(res)); #print(res)
    return events

def getClasses():
    url = "https://app.strigo.io/api/v1/classes"
    res = requests.get(url, headers=headers)
    #print(type(res)); #print(res)
    return res.json()

def getEventClass( eventId ):
    events = getEvents(status='live')
    if VERBOSE: print(f"event={json.dumps(events,  indent=2, sort_keys=True)}")

    for ev in events['data']:
        if ev['id'] == eventId: return ev['class_id']

    return None

def getMyEventField( owner_id_or_email, field='id', status='live', multiple=False ):
    events = getEvents(status=status)
    if VERBOSE: print(f"event={json.dumps(events,  indent=2, sort_keys=True)}")

    #print(events)

    fields=[]
    for ev in events['data']:
        #print(ev)
        if VERBOSE: print(f"eventId={ev['id']} status={ev['status']} owner_mail={ev['owner']['email']}")
        if VERBOSE: print(f"TO MATCH status={status} owner_mail={owner_id_or_email}")
        if ev['status'] == status and \
                (ev['owner']['email'] == owner_id_or_email or \
                 ev['owner']['id'] == owner_id_or_email):
            #print("MATCH")
            if field == '*':
                if VERBOSE: print(f"event={json.dumps(ev,  indent=2, sort_keys=True)}")
            else:
                if VERBOSE: print(f"event[{field}]={ev[field]}")
                if multiple:
                    fields.append(ev[field])
                else:
                    # Verify is this the currentId (does it have a worskspace matching our PRIVATE_IP?)
                    eventId = ev['id']
                    if VERBOSE: print(f"getMyWorkSpaceDetails( {eventId} )={ getMyWorkSpaceDetails( eventId ) }")
                    workspaceDetails=getMyWorkSpaceDetails( eventId )
                    if workspaceDetails[0] != None:
                        if VERBOSE: print(ev[field])
                        return ev[field]
    return fields

def getEvent( eventId ):
    events = getEvents()
    for ev in events['data']:
        if ev['id'] == eventId:
            return ev
    return None

def getEventWorkspaces( eventId ):
    url = f"https://app.strigo.io/api/v1/events/{eventId}/workspaces" 
    res = requests.get(url, headers=headers)
    return res.json()

def getMyWorkSpaceDetails( eventId ):
    workspaces = getEventWorkspaces( eventId )
    if VERBOSE: print(f"workspaces={workspaces}")

    myWorkspace=None

    for ws_data in workspaces['data']:
        workspaceId=ws_data['id']
        workspacePrivateIps=[]
        workspacePublicIps=[]
        if VERBOSE: print(f"workspaceId={workspaceId}")

        owner=ws_data['owner']
        owner_id=owner['id']
        owner_email=owner['email']
        if VERBOSE: print(f"ownerId={owner_id} owner_email={owner_email}")

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
            if VERBOSE: print(f"return ( {owner_id}, {owner_email}, {workspaceId}, {workspacePrivateIps}, {workspacePublicIps} )")
            return ( owner_id, owner_email, workspaceId, workspacePrivateIps, workspacePublicIps )

    # PRIVATE_IP=os.getenv('PRIVATE_IP')
    #return res.json()
    return ( None, None, None, None, None )

def getNumberOfNodes( eventId ):
    ( ownerId, owner_email, workspaceId, workspacePrivateIps, workspacePublicIps ) = \
        getMyWorkSpaceDetails( eventId )
    return len(workspacePrivateIps)

def getMyNodeIndex( eventId ):
    ( ownerId, owner_email, workspaceId, workspacePrivateIps, workspacePublicIps ) = \
        getMyWorkSpaceDetails( eventId )

    for idx in range(len(workspacePrivateIps)):
        private_ip = workspacePrivateIps[idx]
        if private_ip == PRIVATE_IP:
            return idx

    return -1

# Shift off 'prog' argument:
prog=sys.argv[0]; sys.argv=sys.argv[1:]

#def getAllCurrentEventsField( field='id', multiple=True ):
def getAllCurrentEventsField( field='*', multiple=True ):
    if VERBOSE: print(f"getMyEventField( {OWNER_ID_OR_EMAIL}, {field}, {multiple} )")
    return getMyEventField( OWNER_ID_OR_EMAIL, field=field, status='live', multiple=multiple )

def getCurrentEventField( field='id', multiple=False ):
    if VERBOSE: print(f"getMyEventField( {OWNER_ID_OR_EMAIL}, {field}, {multiple} )")
    return getMyEventField( OWNER_ID_OR_EMAIL, field=field, status='live', multiple=multiple )

eventId=None

while len(sys.argv) > 0:
    arg=sys.argv[0]; sys.argv=sys.argv[1:]

    if arg == '-v':
        VERBOSE=True

    if arg == '-o': # Specify owner_id or owner_email to use
        arg=sys.argv[0]; sys.argv=sys.argv[1:]
        OWNER_ID_OR_EMAIL=arg
        if VERBOSE: print(f"Setting OWNER_ID_OR_EMAIL={OWNER_ID_OR_EMAIL}")

    if arg == '-set-e': # Set event_id of current event
        arg=sys.argv[0]; sys.argv=sys.argv[1:]
        eventId=arg
        if VERBOSE: print(f"Setting eventId={eventId}")

    if arg == '-e': # Return event_id of current event
        eventId=getCurrentEventField()
        if VERBOSE:
            print(f"eventId={eventId}")
        else:
            print(eventId)

    if arg == '-E': # Show all events
        eventIds=getAllCurrentEventsField( field='id', multiple=True )
        if VERBOSE:
            print(f"eventIds={eventIds}")
        for eventId in eventIds:
            event=getEvent( eventId )
            print(f"eventId={eventId} status={event['status']} name={event['name']} owner_email={event['owner']['email']}")

    if arg == '-c': # Return class_id of current event
        # if eventId is set use this, else get from current event
        if eventId:
            classId = getEventClass( eventId )
        else:
            classId = getMyEventField( OWNER_ID_OR_EMAIL, field='class_id' )

        if VERBOSE:
            print(f"classId={classId}")
        else:
            print(classId)

    if arg == '-C': # Return all classes
        classes = getClasses()
        #print(f"classes={classes}")
        for _class in classes['data']:
            print(f"classId={_class['id']} name={_class['name']} owner_email={_class['owner']['email']}")

    if arg == '-w': # Return workspace_id of current workspace (this student or owner)
        if not eventId:
            eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        ( ownerId, owner_email, workspaceId, workspacePrivateIps, workspacePublicIps ) = \
            getMyWorkSpaceDetails( eventId )
        print(workspaceId)

    if arg == '-W': # Return workspace_id's of all workspaces of current event
        if not eventId:
            eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        #eventId = getCurrentEventField( 'id' )
        #eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        workspaces = getEventWorkspaces( eventId )
        if VERBOSE: print(f"workspaces={workspaces}")
        for w in workspaces['data']:
            id=w['id']
            #print(f"workspaceId={id} {w}")
            #workspaceId=kmx4yZhao6ni4ScAj {'id': 'kmx4yZhao6ni4ScAj', 'event_id': '8hJkTFjC87yR9Dn9f', 'created_at': '2020-06-04T03:58:02.391Z', 'type': 'host', 'owner': {'id': 'hX8PLJfBX4ojEKZxu', 'email': 'michael.bright@nuaware.com'}, 'online_status': 'deprecated', 'last_seen': '2020-06-04T05:21:08.201Z', 'need_assistance': False}
            print(f"workspaceId={id} event_id={w['event_id']} owner_email={w['owner']['email']} created_at={w['created_at']}")

    if arg == '-WE': # Return workspace_id's of all workspaces of all events
        eventIds=getAllCurrentEventsField( field='id', multiple=True )
        for eventId in eventIds:
            event=getEvent( eventId )
            workspaces = getEventWorkspaces( eventId )
            for w in workspaces['data']:
                id=w['id']
                print(f"workspaceId={id} event_id={w['event_id']} owner_email={w['owner']['email']} created_at={w['created_at']}")

    if arg == '-oid': # Return owner_id of current workspace (this student or owner)
        #eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if not eventId:
            eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        ( ownerId, owner_email, workspaceId, workspacePrivateIps, workspacePublicIps ) = \
            getMyWorkSpaceDetails( eventId )
        print(ownerId)

    if arg == '-oem': # Return owner_email of current workspace (this student or owner)
        #eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if not eventId:
            eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        ( ownerId, owner_email, workspaceId, workspacePrivateIps, workspacePublicIps ) = \
            getMyWorkSpaceDetails( eventId )
        print(owner_email)

    if arg == '-ips': # Return ips of VMs of current workspace (this student or owner)
        #eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if not eventId:
            eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        ( ownerId, owner_email, workspaceId, workspacePrivateIps, workspacePublicIps ) = \
            getMyWorkSpaceDetails( eventId )

        if len(sys.argv) > 0:
            idx=int(sys.argv[0])
            print(f"{workspacePrivateIps[idx]},{workspacePublicIps[idx]}")
            sys.exit(0)

        print( workspacePrivateIps, workspacePublicIps )
        sys.exit(0)

    if arg == '-IPS': # Return ips of VMs of all workspaces of current event
        if not eventId:
            #eventId = getMyEventField( OWNER_ID_OR_EMAIL )
            eventId = getCurrentEventField( 'id' )
        if VERBOSE: print(f"eventId={eventId}")
        workspaces = getEventWorkspaces( eventId )
        if VERBOSE: print(f"workspaces={workspaces}")

        for ws_data in workspaces['data']:
            workspaceId=ws_data['id']
            print(f"workspaceId={workspaceId} event_id={ws_data['event_id']} owner_email={ws_data['owner']['email']} created_at={ws_data['created_at']}")
            url = f"https://app.strigo.io/api/v1/events/{eventId}/workspaces/{workspaceId}/resources"
            workspace = requests.get(url, headers=headers).json()
            for lab_inst in workspace['data']:
                lab_instance_id=lab_inst['id']
                private_ip=lab_inst['private_ip']
                public_ip=lab_inst['public_ip']
                #print(f"workspaceId={id} event_id={w['event_id']} owner_email={w['owner']['email']} created_at={w['created_at']}")
                #if VERBOSE: print(f"lab_id={lab_instance_id} private_ip=${private_ip} public_ip={public_ip}")
                print(f"  lab_id={lab_instance_id} private_ip=${private_ip} public_ip={public_ip}")

        sys.exit(0)

    if arg == '-idx': # Get index of the current VM e.g. so that 1 is Master, 2 is Slave etc ...
        if not eventId:
            eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        idx = getMyNodeIndex( eventId )
        print(idx)

    if arg == '-nodes': # Get number of nodes/VMs for the current student workspace
        #eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if not eventId:
            eventId = getMyEventField( OWNER_ID_OR_EMAIL )
        if VERBOSE: print(f"eventId={eventId}")
        nodes = getNumberOfNodes( eventId )
        print(nodes)

