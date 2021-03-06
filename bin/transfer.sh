#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### Define callback function
HOST_CALLBACK="host_transfer"
host_transfer() {
    _echo "HOST: $HOST_NAME ($IP)"

    # Check dirs and flags
    BACKUP_DIR_HOST="$BACKUP_DIR/$HOST_NAME"
    BACKUP_DIR_CUR="$BACKUP_DIR/$HOST_NAME/$DATE_TODAY"
    if [ ! -e $BACKUP_DIR_HOST ]; then

        $DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-location-create.sh "$BACKUP_DIR" "$HOST_NAME" &&
        $DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-instance-prepare-new.sh "$BACKUP_DIR" "$HOST_NAME" "$DATE_TODAY" &&
        touch $BACKUP_DIR_CUR/$FLAG_PREPARED

    else

        if [ ! -e $BACKUP_DIR_CUR ]; then
            $DIR_APP_BIN/prepare-single.sh $HOST_NAME $DATE_TODAY
            if [ "$?" != "0" ]; then
                _error "Prepare script returned non-zero status"
            fi
        fi
    fi


    # Check if already complete
    if [ -e $BACKUP_DIR_CUR/$FLAG_COMPLETE ]; then
        _echo "  Backup already complete."
        return 0
    fi

    if [ ! -e $BACKUP_DIR_CUR/$FLAG_PREPARED ]; then
        $DIR_APP_BIN/prepare-single.sh $HOST_NAME $DATE_TODAY
        if [ "$?" != "0" ]; then
            _error "Prepare script returned non-zero status"
        fi
    fi

    ### Check .prepared flag
    if [ ! -e $BACKUP_DIR_CUR/$FLAG_PREPARED ]; then
        _error "Unable to prepare for $HOST_NAME for $DATE_TODAY - flag $FLAG_PREPARE not found"
    fi


    # Process modules
    _echo "  Processing modules '$MODULES':"
    for MODULE in `echo $MODULES`; do
	_echo -n "    Processing module $MODULE... "

	if [ -e $BACKUP_DIR_CUR/$FLAG_COMPLETE_MODULE$MODULE ]; then
	    _echo "      done already."
	    continue
	fi
	_echo ""
	_echo "      ------[ START rsync output ]-----------------------------------"

        CMD="$PATH_RSYNC -e '$PATH_SSH -o PasswordAuthentication=no -l $SSH_USER -p $PORT' --rsync-path=$PATH_RSYNC -avz --delete --delete-excluded --numeric-ids $IP::$MODULE $BACKUP_DIR_CUR/$MODULE"
        #if [ "$VERBOSE_OUTPUT" != "yes" ]; then
    	    CMD="$CMD >> $BACKUP_DIR_CUR/.log.$MODULE 2>&1"
	    _echo "      Saving log in file $BACKUP_DIR_CUR/.log.$MODULE"
    	#fi

        #_echo "      Executing command: $CMD"
        eval $CMD
	RSYNC_RESULT=$?
	_echo "      ------[ END rsync output ]-----------------------------------"

        if [ "$RSYNC_RESULT" == "0" ]; then
	    _echo "      Setting the $FLAG_COMPLETE_MODULE$MODULE flag"
	    touch $BACKUP_DIR_CUR/$FLAG_COMPLETE_MODULE$MODULE
	elif [ "$RSYNC_RESULT" == "24" ]; then
	    _echo "      Setting the $FLAG_COMPLETE_MODULE$MODULE flag (some files vanished along the way)"
	    touch $BACKUP_DIR_CUR/$FLAG_COMPLETE_MODULE$MODULE
	else
	    echo "      Error occured, see the log file $BACKUP_DIR_CUR/.log.$MODULE"
	    RETURN_VALUE='1'
	fi
    done


    # Check if all modules have been processed successfuly
    COMPLETE_FLAG_FILE="$BACKUP_DIR_CUR/$FLAG_COMPLETE"
    if [ -e $COMPLETE_FLAG_FILE ]; then
	_echo "  Backup complete, flag file exists: $COMPLETE_FLAG_FILE"
	continue
    fi

    ALL_MODULES_DONE='1'
    for MODULE in `echo $MODULES`; do
	if [ ! -e $BACKUP_DIR_CUR/$FLAG_COMPLETE_MODULE$MODULE ]; then
    	    ALL_MODULES_DONE='0'
	fi
    done
    if [ "$ALL_MODULES_DONE" == "1" ]; then
	_echo "  All modules processed correctly. Setting flag file: $COMPLETE_FLAG_FILE"
	touch $COMPLETE_FLAG_FILE
    else
	_echo "  WARNING: Some modules failed to process correctly."
	RETURN_VALUE='1'
    fi


    return $RETURN_VALUE
}



### Loop through hosts
loop_hosts $HOST_CALLBACK
RETURN_VALUE=$?
if [ "$RETURN_VALUE" == "0" ]; then
    _echo "All hosts have been processed correctly."
else
    _echo "WARNING: There were some errors during backup transfer process."
    _echo "WARNING: Please inspect results manually."
fi



### Remove pid file
remove_pid_file



### Start preparation process for next backup (TODO: make it configurable?)
if [ "$RETURN_VALUE" == "0" ]; then
    _echo "Starting preparation for next day..."
    $INSTALL_DIR/bin/prepare.sh
fi



### Exit
exit $RETURN_VALUE
