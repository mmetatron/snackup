#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### For which date to verify
if [ "x$1" != "x" ]; then
    DATE_TO_VERIFY="$1"
else
    DATE_TO_VERIFY="$DATE_TODAY"
fi



### Define callback function
HOST_CALLBACK="host_verify"
host_verify() {
    _echo "HOST: $HOST_NAME"

    if [ ! -e $BACKUP_DIR/$HOST_NAME ]; then
        echo "    WARNING: Host backup directory not found"
        return 2
    fi
    if [ ! -e $BACKUP_DIR/$HOST_NAME/$DATE_TO_VERIFY ]; then
        echo "    Host backup directory for date $DATE_TO_VERIFY not found"
        return 2
    fi

    for MODULE in $MODULES; do
	_echo -n "    Verifying module $MODULE... "
	if [ ! -e $BACKUP_DIR/$HOST_NAME/$DATE_TO_VERIFY/$MODULE ]; then
	    echo "module directory not found"
	    return 3
	fi
	if [ ! -d $BACKUP_DIR/$HOST_NAME/$DATE_TO_VERIFY/$MODULE ]; then
	    echo "not a directory"
	    return 3
	fi
	if [ ! -e $BACKUP_DIR/$HOST_NAME/$DATE_TO_VERIFY/$FLAG_COMPLETE_MODULE$MODULE ]; then
	    echo "module flag not found"
	    return 3
	fi
	_echo "ok"
    done

    ### Check .complete flag
    if [ ! -e $BACKUP_DIR/$HOST_NAME/$DATE_TO_VERIFY/$FLAG_COMPLETE ]; then
        echo "    Host flag '$FLAG_COMPLETE' not found"
        return 4
    fi
    return 0
}



### Loop through hosts
echo "Verifying backup transfer status for date $DATE_TO_VERIFY... "
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



### Exit
exit $RETURN_VALUE
