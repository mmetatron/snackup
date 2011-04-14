#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### Define callback function
ROUTER_CALLBACK="router_transfer"
router_transfer() {
    _echo "ROUTER: $HOST_NAME"

    # Check dirs and flags
    if [ ! -e $BACKUP_DIR/$HOST_NAME ]; then
        mkdir $BACKUP_DIR/$HOST_NAME
    fi
    BACKUP_DIR_CUR="$BACKUP_DIR/$HOST_NAME/$DATE_TODAY"

    if [ ! -e $BACKUP_DIR_CUR ]; then
	mkdir $BACKUP_DIR_CUR
    fi

    # Check if already complete
    COMPLETE_FLAG_FILE="$BACKUP_DIR_CUR/$FLAG_COMPLETE"
    if [ -e "$COMPLETE_FLAG_FILE" ]; then
	_echo "  Already complete."
	return
    fi


    # Process modules
    _echo "  Processing files '$MODULES':"
    for MODULE in `echo $MODULES`; do
	_echo -n "    Processing file $MODULE... "

	if [ -e $BACKUP_DIR_CUR/$FLAG_COMPLETE_MODULE$MODULE ]; then
	    _echo "      done already."
	    continue
	fi

	# Generate SCP file
	SOURCE_SCP_FILE="$INSTALL_DIR/bin/router-scp.sh.template"
	DEST_SCP_FILE="/tmp/router-scp.sh"
	umask 0077
	rm -f $DEST_SCP_FILE
	cat $SOURCE_SCP_FILE \
        | sed -e "s/SSH_USERNAME/$SSH_USERNAME/" \
        | sed -e "s/SSH_PASSWORD/$SSH_PASSWORD/" \
        | sed -e "s/SSH_IP/$IP/" \
        | sed -e "s/SSH_PORT/$PORT/" \
        | sed -e "s/SRC_FILE/$MODULE/" \
        | sed -e "s#DEST_FILE#$BACKUP_DIR_CUR/$MODULE#" \
	> $DEST_SCP_FILE
	chmod 700 $DEST_SCP_FILE

	_echo ""
	_echo "      ------[ START scp output ]-----------------------------------"
	$DEST_SCP_FILE >> $BACKUP_DIR_CUR/.log.$MODULE
	_echo "      ------[ END scp output ]-----------------------------------"

        if [ ! -e "$BACKUP_DIR_CUR/$MODULE" ]; then
	    echo "      Error occured (file not found), see the log file $BACKUP_DIR_CUR/.log.$MODULE"
	    RETURN_VALUE='1'
	    continue
	elif [ ! -s "$BACKUP_DIR_CUR/$MODULE" ]; then
	    echo "      Error occured (file empty), see the log file $BACKUP_DIR_CUR/.log.$MODULE"
	    RETURN_VALUE='1'
	    continue
	fi

	# Check if startup-config and running config differ
	_echo "      Setting the $FLAG_COMPLETE_MODULE$MODULE flag"
	touch $BACKUP_DIR_CUR/$FLAG_COMPLETE_MODULE$MODULE
    done


    # Check if all modules have been processed successfuly
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
	return 1
    fi


    # Sync the disks after each router
    _echo -n "  Syncing the disks... "
    sync
    _echo "done."


    # Compare startup and running config
    RES=`diff "$BACKUP_DIR_CUR/nvram:startup-config" "$BACKUP_DIR_CUR/system:running-config" -I '^ntp clock-period [0-9]\+$' -I '^! No configuration change since last restart$' -I '^! Last configuration change at ' -I '^! NVRAM config last updated at ' | grep -c . | cat`
    if [ "$RES" != "0" ]; then
	_echo "  WARNING: Startup and running config differ."
	return 1
    fi

    return $RETURN_VALUE
}



### Loop through hosts
loop_routers $ROUTER_CALLBACK
RETURN_VALUE=$?
if [ "$RETURN_VALUE" == "0" ]; then
    _echo "All routers have been processed correctly."
else
    _echo "WARNING: There were some errors during backup transfer process."
    _echo "WARNING: Please inspect results manually."
fi



### Remove pid file
remove_pid_file



### Exit
exit $RETURN_VALUE
