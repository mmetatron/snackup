#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### Define callback function
HOST_CALLBACK="host_transfer"
host_transfer() {
    echo "transfering host"
}



### Loop through hosts
loop_hosts $HOST_CALLBACK



exit;




# Get number of hosts to backup
HOSTS_COUNT=`cat $HOSTS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | grep -c .`
RET_VAL=$?
if [ "$RET_VAL" != "0" ]; then
    echo "ERROR: Unable to get number of hosts to backup"
    exit 1
fi
if [ "$HOSTS_COUNT" -lt "1" ]; then
    echo "ERROR: No hosts to backup?"
    exit 1
fi



# Loop through the config file and parse it
RETURN_VALUE='0'
#cat $HOSTS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | sed -e 's/\s\+/ /g'| while read HOST_LINE; do
for i in `seq 1 $HOSTS_COUNT`; do
    HOST_LINE=`cat $HOSTS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | sed -e 's/\s\+/ /g' | head -n $i | tail -n 1`
    HOST_NAME=`echo $HOST_LINE | cut -d ' ' -f 1`
    IP_PORT=`echo $HOST_LINE | cut -d ' ' -f 2`
    IP=`echo $IP_PORT | cut -d ':' -f 1`

    # Check if port is given
    if [ "`echo $IP_PORT | grep ':'`" == "" ]; then
	PORT=$DEFAULT_PORT
    elif [ "`echo $IP_PORT | grep -v ':\$'`" == "" ]; then
	PORT=$DEFAULT_PORT
    else
	PORT=`echo $IP_PORT | cut -d ':' -f 2`
    fi

    # Parse modules
    MODULES=$DEFAULT_MODULES
    SPECIFIC_MODULES=`echo $HOST_LINE | cut -d ' ' -f 3-`
    if [ "$SPECIFIC_MODULES" != "" ]; then
	MODULES=$SPECIFIC_MODULES
    fi



    ############################################################################
    # Start the backup
    ############################################################################
    _echo "Host: $HOST_NAME"

    # Create backup directory
    mkdir -p $BACKUPDIR/$HOST_NAME

    # Get last and current backup directory
    # FIXME check last 14 days for last .complete backup and use that, otherwise start anew
    TMP=`ls $BACKUPDIR/$HOST_NAME | grep [0-9]\$ | tail -n 1`
    if [ "$TMP" != "" ]; then
	BACKUPDIR_LAST="$BACKUPDIR/$HOST_NAME/$TMP"
    else
	BACKUPDIR_LAST=""
    fi
    BACKUPDIR_CUR="$BACKUPDIR/$HOST_NAME/`date +'%Y-%m-%d'`"
    COMPLETE_FLAG_FILE="$BACKUPDIR_CUR/$COMPLETE_FLAG_FILE_NAME"

    # Copy the last backup if it is available
    if [ "$BACKUPDIR_LAST" != "" ]; then
	if [ -e $BACKUPDIR_CUR ]; then
	    _echo "  Target directory already exists: $BACKUPDIR_CUR"
	else
	    _echo "  Hard linking: "
	    _echo "    from: $BACKUPDIR_LAST"
	    _echo "      to: $BACKUPDIR_CUR"
	    cp -al $BACKUPDIR_LAST $BACKUPDIR_CUR
	    _echo "    done."

	    _echo -n "  Removing flags and logs... "
	    rm -f $BACKUPDIR_CUR/.done.*
	    rm -f $BACKUPDIR_CUR/.log.*
	    rm -f $BACKUPDIR_CUR/$COMPLETE_FLAG_FILE_NAME
	    _echo "done."
	fi
    else
	_echo "  Creating directory: $BACKUPDIR_CUR"
	mkdir -p $BACKUPDIR_CUR
        _echo "    done."
    fi

    # Check if flag for complete backup already exists
    if [ -e $COMPLETE_FLAG_FILE ]; then
	_echo "  Flag file for complete backup already exists, therefore skipping"
	continue
    fi



    # Process modules
    _echo "  Processing modules '$MODULES':"
    for MODULE in `echo $MODULES`; do
	_echo -n "    Processing module $MODULE... "

	if [ -e $BACKUPDIR_CUR/.done.$MODULE ]; then
	    _echo "      done already."
	    continue
	fi
	_echo ""
	_echo "      ------[ START rsync output ]-----------------------------------"

        CMD="$RSYNC_PATH -e '$SSH_PATH -o PasswordAuthentication=no -l root -p $PORT' --rsync-path=$RSYNC_PATH -avz --delete --delete-excluded $IP::$MODULE $BACKUPDIR_CUR/$MODULE"
        #if [ "$VERBOSE_OUTPUT" != "yes" ]; then
    	    CMD="$CMD >> $BACKUPDIR_CUR/.log.$MODULE 2>&1"
	    _echo "      Saving log in file $BACKUPDIR_CUR/.log.$MODULE"
    	#fi

        #_echo "      Executing command: $CMD"
        eval $CMD
	RSYNC_RESULT=$?
	_echo "      ------[ END rsync output ]-----------------------------------"

        if [ "$RSYNC_RESULT" == "0" ]; then
	    _echo "      Setting the .done.$MODULE flag"
	    touch $BACKUPDIR_CUR/.done.$MODULE
	else
	    echo "      Error occured, see the log file $BACKUPDIR_CUR/.log.$MODULE"
	    RETURN_VALUE='1'
	fi

	# Sync the disks after each module is processed
	_echo -n "      Syncing the disks... "
	/usr/bin/sync
        _echo "done."
    done



    # Check if all modules have been processed successfuly
    COMPLETE_FLAG_FILE="$BACKUPDIR_CUR/$COMPLETE_FLAG_FILE_NAME"
    if [ -e $COMPLETE_FLAG_FILE ]; then
	_echo "  Backup complete, flag file exists: $COMPLETE_FLAG_FILE"
	continue
    fi

    ALL_MODULES_DONE='1'
    for MODULE in `echo $MODULES`; do
	if [ ! -e $BACKUPDIR_CUR/.done.$MODULE ]; then
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
done



# Remove pid file
_echo -n "Removing lock file... "
rm $PIDFILE
_echo "done."



# Signal end time
_echo "Finishing at `date`"
_echo
exit $RETURN_VALUE
