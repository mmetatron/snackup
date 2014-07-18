#!/bin/bash



### Start with common file
#
. `dirname $BASH_SOURCE`/../../_bootstrap.sh



### Check args
#
if [ "$#" != "2" ]; then
    _error "Exactly two arguments required: backup storage location root and hostname"
fi
BACKUP_LOCATION_ROOT="$1"
HOST_NAME="$2"
HOST_BACKUP_LOCATION="$BACKUP_LOCATION_ROOT/$HOST_NAME"



### Check host backup location
#
if [ -e $HOST_BACKUP_LOCATION ]; then
    if [ ! -d $HOST_BACKUP_LOCATION ]; then
        _error "Host backup location exists, but is not a directory"
    else
        echo "      POSIX: Host backup location already exists: $HOST_BACKUP_LOCATION"
    fi
fi



### Create new subvolume
#
echo "      POSIX: Creating directory $HOST_BACKUP_LOCATION" &&
mkdir $HOST_BACKUP_LOCATION &&
echo "      POSIX: Operation complete."
