#!/bin/bash



### Start with common file
#
. `dirname $BASH_SOURCE`/../../_bootstrap.sh



### Check args
#
if [ "$#" != "4" ]; then
    _error "Exactly four arguments required: backup storage location root, hostname, existing backup date to clone and backup date to prepare"
fi
BACKUP_LOCATION_ROOT="$1"
HOST_NAME="$2"
BACKUP_INSTANCE_DATE_EXISTING="$3"
BACKUP_INSTANCE_DATE_PREPARE="$4"
HOST_BACKUP_LOCATION="$BACKUP_LOCATION_ROOT/$HOST_NAME"
HOST_BACKUP_INSTANCE_LOCATION_EXISTING="$BACKUP_LOCATION_ROOT/$HOST_NAME/$BACKUP_INSTANCE_DATE_EXISTING"
HOST_BACKUP_INSTANCE_LOCATION_PREPARE="$BACKUP_LOCATION_ROOT/$HOST_NAME/$BACKUP_INSTANCE_DATE_PREPARE"



### Check host backup location
#
if [ ! -d $HOST_BACKUP_LOCATION ]; then
    _error "Host backup location does not exist: $HOST_BACKUP_LOCATION"
fi



### Check existing and upcoming host backup instance locations
#
if [ ! -d $HOST_BACKUP_INSTANCE_LOCATION_EXISTING ]; then
    _error "Existing host backup instance location not found: $HOST_BACKUP_INSTANCE_LOCATION_EXISTING"
fi
if [ -e $HOST_BACKUP_INSTANCE_LOCATION_PREPARE ]; then
    _error "New host backup instance location already exist: $HOST_BACKUP_INSTANCE_LOCATION_PREPARE"
fi



### Move existing snapshot - just move directory
#
echo "      BTRFS: Renaming existing subvolume:" &&
echo "        Src: $HOST_BACKUP_INSTANCE_LOCATION_EXISTING" &&
echo "       Dest: $HOST_BACKUP_INSTANCE_LOCATION_PREPARE" &&
mv   $HOST_BACKUP_INSTANCE_LOCATION_EXISTING   $HOST_BACKUP_INSTANCE_LOCATION_PREPARE &&
echo "      BTRFS: Operation complete."
