#!/bin/bash



### Start with common file
#
. `dirname $BASH_SOURCE`/../../_bootstrap.sh



### Check args
#
if [ "$#" != "3" ]; then
    _error "Exactly three arguments required: backup storage location root, hostname and backup date to prepare"
fi
BACKUP_LOCATION_ROOT="$1"
HOST_NAME="$2"
BACKUP_INSTANCE_DATE="$3"
HOST_BACKUP_LOCATION="$BACKUP_LOCATION_ROOT/$HOST_NAME"
HOST_BACKUP_INSTANCE_LOCATION="$BACKUP_LOCATION_ROOT/$HOST_NAME/$BACKUP_INSTANCE_DATE"



### Check host backup location
#
if [ ! -d $HOST_BACKUP_LOCATION ]; then
    `dirname $BASH_SOURCE`/host-backup-location-create.sh "$BACKUP_LOCATION_ROOT" "$HOST_NAME"
fi



### Check host backup instance location
#
if [ -e $HOST_BACKUP_INSTANCE_LOCATION ]; then
    _error "Host backup instance location already exists: $HOST_BACKUP_INSTANCE_LOCATION"
fi



### Create new subvolume
#
echo "      POSIX: Creating new directory $HOST_BACKUP_INSTANCE_LOCATION" &&
mkdir $HOST_BACKUP_INSTANCE_LOCATION &&
echo "      POSIX: Operation complete."
