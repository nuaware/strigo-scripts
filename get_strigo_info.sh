#!/bin/bash

## -- usage: ----------------------------------------------------

# > ./get_strigo_info.sh nuaware_pcc_vars.rc -E
# eventId=YY4wZyFm6GyiD7EER status=live name=Untitled training event owner_email=michael.bright@nuaware.com
# eventId=2ZCXwpffECibjSLZB status=live name=Untitled training event owner_email=michael.bright@nuaware.com

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


./get_strigo_info.py $*

