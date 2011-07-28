#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### Settings
BACKUP_PURGE_SCRIPT_FILE="`dirname $0`/../tmp/hosts-purge.sh"



### Define callback function
HOST_CALLBACK="host_purge_generate"
host_purge_generate() {
    _echo "HOST: $HOST_NAME"

    if [ ! -e $BACKUP_DIR/$HOST_NAME ]; then
        echo "#    WARNING: Host backup directory not found"
        return 2
    fi

    `dirname $0`/hosts-purge-generate-single.php $BACKUP_DIR/$HOST_NAME >> $BACKUP_PURGE_SCRIPT_FILE
}



### Remove old purge script if exists and reinit it
if [ -e $BACKUP_PURGE_SCRIPT_FILE ]; then
    rm $BACKUP_PURGE_SCRIPT_FILE
fi
echo "renice 20 -p \$\$" > $BACKUP_PURGE_SCRIPT_FILE



### Loop through hosts
echo "Generating host backup purge script... "
echo "  File: `readlink -f $BACKUP_PURGE_SCRIPT_FILE`"
loop_hosts $HOST_CALLBACK
RETURN_VALUE=$?
if [ "$RETURN_VALUE" == "0" ]; then
    _echo "Done."
    _echo
    _echo "Backup purge script generated successfully, but please inspect it manually"
    _echo "before you execute it."
    _echo "You can start it like this to put it into background:"
    _echo
    _echo "  sh `readlink -f $BACKUP_PURGE_SCRIPT_FILE` > `readlink -f $BACKUP_PURGE_SCRIPT_FILE`.log 2>&1 &"
    _echo
else
    _echo "WARNING: There were some errors during backup purge script generation process."
    _echo "WARNING: Please inspect results manually."
fi



### Remove pid file
remove_pid_file



### Exit
exit $RETURN_VALUE
