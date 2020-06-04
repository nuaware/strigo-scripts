#!/bin/bash

## -- usage: ----------------------------------------------------

# > ./get_strigo_info.sh nuaware_pcc_vars.rc -E
# eventId=YY4wZyFm6GyiD7EER status=live name=Untitled training event owner_email=michael.bright@nuaware.com
# eventId=2ZCXwpffECibjSLZB status=live name=Untitled training event owner_email=michael.bright@nuaware.com

# > ./get_strigo_info.sh nuaware_pcc_vars.rc --private-ip 172.31.10.64 -v -W
# eventId=jRLS35YPuBGdTYrJw
# workspaces={'result': 'success', 'data': [{'id': 'DAjXBsDJrW4NXRBiz', 'event_id': 'jRLS35YPuBGdTYrJw', 'created_at': '2020-06-04T08:24:59.267Z', 'type': 'student', 'owner': {'id': 'TQhtXqawCNLnMui2p', 'email': 'mjbrightfr@gmail.com'}, 'online_status': 'deprecated', 'last_seen': '2020-06-04T08:46:21.258Z', 'need_assistance': False}, {'id': 'g2NcRLH4J7T2TfYen', 'event_id': 'jRLS35YPuBGdTYrJw', 'created_at': '2020-06-04T08:21:41.786Z', 'type': 'host', 'owner': {'id': 'hX8PLJfBX4ojEKZxu', 'email': 'michael.bright@nuaware.com'}, 'online_status': 'deprecated', 'last_seen': '2020-06-04T09:03:23.029Z', 'need_assistance': False}]}
#
# > ./get_strigo_info.sh nuaware_pcc_vars.rc -W
# Traceback (most recent call last):
#   File "./get_strigo_info.py", line 223, in <module>
#       for w in workspaces['data']:
# 	      KeyError: 'data'

# > ./get_strigo_info.sh nuaware_pcc_vars.rc -IPS
# Traceback (most recent call last):
#   File "./get_strigo_info.py", line 276, in <module>
#     for ws_data in workspaces['data']:
#       KeyError: 'data'

## -- functions: ------------------------------------------------

die() {
    echo "$0: die - $*" >&2
    exit 1
}

## -- arguments: ------------------------------------------------

VERBOSE=""
[ "$1" = "-v" ] && { VERBOSE="-v"; shift; }

RCFILE=$1
shift

[ -z "$RCFILE"   ] && die "Usage: $0 <rcfile>"
[ ! -f "$RCFILE" ] && die "Usage: No such rcfile as <$RCFILE>"

export PRIVATE_IP="unset"
export PUBLIC_IP="unset"

# If running in an ec2 VM: assume the case if ec2metatdata present:
which ec2metadata 2>/dev/null && {
	# Check we're not running under WSL:
	uname -a | grep microsoft ||
	    export PRIVATE_IP=$(ec2metadata --local-ipv4) PUBLIC_IP=$(ec2metadata --public-ipv4)
}

if [ "$1" = "--private-ip" ]; then
    shift; export PRIVATE_IP="$1"; shift
fi

if [ "$1" = "--public-ip" ]; then
    shift; export PUBLIC_IP="$1"; shift
fi

. $RCFILE

#ARGS="$VERBOSE -oem $OWNER_ID_OR_EMAIL"

#./get_strigo_info.py $ARGS $*
set -x
./get_strigo_info.py $*

