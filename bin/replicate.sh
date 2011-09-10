#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### Date to replicate
if [ "x$1" != "x" ]; then
    DATE_TO_REPLICATE="$1"
else
    DATE_TO_REPLICATE="$DATE_YESTERDAY"
fi



### Define callback function
HOST_CALLBACK="host_replicate"
host_replicate() {
    _echo "HOST: $HOST_NAME"

    # Check dirs and flags
    BACKUP_DIR_HOST="$BACKUP_DIR/$HOST_NAME"
    BACKUP_DIR_CUR="$BACKUP_DIR/$HOST_NAME/$DATE_TO_REPLICATE"

    if [ ! -e $BACKUP_DIR/$HOST_NAME ]; then

	# Create new dir and set .prepared flag
        mkdir -p $BACKUP_DIR_CUR
	touch $BACKUP_DIR_CUR/$FLAG_PREPARED

    else

	# Prepare if not yet prepared
        if [ ! -e $BACKUP_DIR_CUR ]; then
    	    $INSTALL_DIR/bin/prepare-single.sh $HOST_NAME $DATE_TO_REPLICATE
	    if [ "$?" != "0" ]; then
		_error "Prepare script returned non-zero status"
	    fi
	fi

    fi

    # Check if already complete
    if [ -e $BACKUP_DIR_CUR/$FLAG_COMPLETE ]; then
	_echo "  Already complete."
	return 0
    fi

    if [ ! -e $BACKUP_DIR_CUR/$FLAG_PREPARED ]; then
	$INSTALL_DIR/bin/prepare-single.sh $HOST_NAME $DATE_TO_REPLICATE
        if [ "$?" != "0" ]; then
	    _error "Prepare script returned non-zero status"
	fi
    fi

    ### Check .prepared flag
    if [ ! -e $BACKUP_DIR_CUR/$FLAG_PREPARED ]; then
	_error "Unable to prepare for $HOST_NAME for $DATE_TO_REPLICATE - flat $FLAG_PREPARE not found"
    fi


    # Process the host
    REPLICATE_SRC=$REPLICATE_SOURCE_IP:$REPLICATE_SOURCE_DIR/$HOST_NAME/$DATE_TO_REPLICATE/
    REPLICATE_DEST=$BACKUP_DIR_CUR/content/
    CMD="$PATH_RSYNC -e '$PATH_SSH -o PasswordAuthentication=no -l root -p $REPLICATE_SOURCE_PORT' --rsync-path=$PATH_RSYNC -avz --delete --delete-excluded --numeric-ids --exclude='.complete' $REPLICATE_SRC $REPLICATE_DEST"
    #if [ "$VERBOSE_OUTPUT" != "yes" ]; then
	CMD="$CMD >> $BACKUP_DIR_CUR/.log.replication 2>&1"
	_echo "      Saving log in file $BACKUP_DIR_CUR/.log.replication"
    #fi

    #_echo "      Executing command: $CMD"
    eval $CMD
    RSYNC_RESULT=$?

    if [ "$RSYNC_RESULT" == "0" ]; then
	_echo "      Setting the $FLAG_COMPLETE_MODULE$MODULE flag"
	touch $BACKUP_DIR_CUR/$FLAG_COMPLETE
    elif [ "$RSYNC_RESULT" == "24" ]; then
	_echo "      Setting the $FLAG_COMPLETE flag (some files vanished along the way)"
	touch $BACKUP_DIR_CUR/$FLAG_COMPLETE
    else
	echo "      Error occured, see the log file $BACKUP_DIR_CUR/.log.replication"
	RETURN_VALUE='1'
    fi

    # Sync the disks after each host is processed
    _echo -n "      Syncing the disks... "
    sync
    _echo "done."

    return $RETURN_VALUE
}



### Loop through hosts
loop_hosts $HOST_CALLBACK
RETURN_VALUE=$?
if [ "$RETURN_VALUE" == "0" ]; then
    _echo "All hosts have been processed correctly."
else
    _echo "WARNING: There were some errors during backup replication process."
    _echo "WARNING: Please inspect results manually."
fi



### Remove pid file
remove_pid_file



### Exit
exit $RETURN_VALUE
