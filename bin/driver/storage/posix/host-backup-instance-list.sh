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


### Check directory
#
if [ ! -d $HOST_BACKUP_LOCATION ]; then
    _error "Host backup location does not exist: $HOST_BACKUP_LOCATION"
fi



### Return dates
#
ls $HOST_BACKUP_LOCATION | grep '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$' | sort -r



### Exit
#
exit 0
