#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### For which date to prepare
if [ "x$1" != "x" ]; then
    DATE_TO_PREPARE_FOR="$1"
else
    DATE_TO_PREPARE_FOR="$DATE_TOMORROW"
fi



### Define callback function
HOST_CALLBACK="host_prepare"
host_prepare() {
    _echo "HOST: $HOST_NAME"

    # Check host backup location
    if [ ! -e $BACKUP_DIR/$HOST_NAME ]; then
        $DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-location-create.sh "$BACKUP_DIR" "$HOST_NAME"
    fi

    # Try to prepare it
    $INSTALL_DIR/bin/prepare-single.sh $HOST_NAME $DATE_TO_PREPARE_FOR
    RES="$?"

    if [ "$RES" != "0" ]; then
	_error "Prepare script returned non-zero status"
    fi

    ### Check .prepared flag
    if [ ! -e $BACKUP_DIR/$HOST_NAME/$DATE_TO_PREPARE_FOR/$FLAG_PREPARED ]; then
        _error "Host flag '$FLAG_PREPARED' not found"
    fi

    return 0
}



### Loop through hosts
loop_hosts $HOST_CALLBACK
RETURN_VALUE=$?
if [ "$RETURN_VALUE" == "0" ]; then
    _echo "All hosts have been prepared correctly."
else
    _echo "WARNING: There were some errors during backup preparation process."
    _echo "WARNING: Please inspect results manually."
fi



### Remove pid file
remove_pid_file



### Exit
exit $RETURN_VALUE
