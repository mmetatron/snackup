#!/bin/bash



### Start with common file
. `dirname $0`/_common.sh



### Check args
if [ "$#" != "2" ]; then
    _error "Exactly two arguments required: hostname and date to prepare for"
fi
HOST_NAME="$1"
DATE_PREPARE="$2"



### Check if backup dir for hostname exists
if [ ! -e $BACKUP_DIR/$HOST_NAME ]; then
    _error "Host backup directory does not exist: $BACKUP_DIR/$HOST_NAME"
fi



### Check if date format is valid
check_date $DATE_PREPARE
RES=$?
if [ "$RES" == "1" ]; then
    _error "Invalid date to prepare for specified: $DATE_PREPARE"
fi



### Check if it is already prepared or completed
if [ -e $BACKUP_DIR/$HOST_NAME/$DATE_PREPARE.tmp/$FLAG_PREPARING ]; then
    # FIXME search for process and check
    _error "Already preparing by some other process"
fi
if [ -e $BACKUP_DIR/$HOST_NAME/$DATE_PREPARE/$FLAG_PREPARED ]; then
    _exit "  Already prepared"
fi
if [ -e $BACKUP_DIR/$HOST_NAME/$DATE_PREPARE/$FLAG_PROCESSING ]; then
    _error "Already processing by some other process?"
fi
if [ -e $BACKUP_DIR/$HOST_NAME/$DATE_PREPARE/$FLAG_COMPLETE ]; then
    _error "Already complete"
fi



### Find previous backup to copy from
BACKUP_DATES=`$DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-instance-list.sh "$BACKUP_DIR" "$HOST_NAME"`

# If none
if [ "$BACKUP_DATES" == "" ]; then
    echo "  WARNING: No previous backup found, creating new dir for $DATE_PREPARE"
    $DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-instance-prepare-new.sh "$BACKUP_DIR" "$HOST_NAME" "$DATE_PREPARE"
    touch $BACKUP_DIR/$HOST_NAME/$DATE_PREPARE/$FLAG_PREPARED
    _exit
fi

# Get latest completed
LAST_COMPLETED_DATE=""
for BACKUP_DATE in $BACKUP_DATES; do
    if [ -e $BACKUP_DIR/$HOST_NAME/$BACKUP_DATE/$FLAG_COMPLETE ]; then
        LAST_COMPLETED_DATE=$BACKUP_DATE
        break
    fi
done

# Get latest prepared
LAST_PREPARED_DATE=""
for BACKUP_DATE in $BACKUP_DATES; do
    if [ -e $BACKUP_DIR/$HOST_NAME/$BACKUP_DATE/$FLAG_PREPARED ]; then
        LAST_PREPARED_DATE=$BACKUP_DATE
        break
    fi
done

# If no complete or prepared, signal error
if [ "$LAST_COMPLETED_DATE" == "" ]; then
    if [ "$LAST_PREPARED_DATE" == "" ]; then
        _error "No complete nor prepared backup to use for preparation"
    fi
fi

# If latest prepared backup date is greater than complete date, use that instead
if [ "$LAST_PREPARED_DATE" '>' "$LAST_COMPLETED_DATE" ]; then
    PREPARATION_METHOD="move"
    BACKUP_DATE_TO_USE="$LAST_PREPARED_DATE"
else
    PREPARATION_METHOD="clone"
    BACKUP_DATE_TO_USE="$LAST_COMPLETED_DATE"
fi



### Prepare destination directory paths
BACKUP_DIR_LAST="$BACKUP_DIR/$HOST_NAME/$BACKUP_DATE_TO_USE"
BACKUP_DIR_CUR_TMP="$BACKUP_DIR/$HOST_NAME/$DATE_PREPARE.tmp"
BACKUP_DIR_CUR="$BACKUP_DIR/$HOST_NAME/$DATE_PREPARE"



### Prepare by moving
if [ "$PREPARATION_METHOD" == "move" ]; then
    _echo "  Last backup is not complete, only prepared, let's move that: "
    _echo "    from: $BACKUP_DIR_LAST"
    _echo "      to: $BACKUP_DIR_CUR_TMP"
    $DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-instance-prepare-move.sh "$BACKUP_DIR" "$HOST_NAME" "$BACKUP_DATE_TO_USE" "$DATE_PREPARE.tmp"
    _echo "    done."
elif [ "$PREPARATION_METHOD" == "clone" ]; then
    _echo "  Cloning: "
    _echo "    from: $BACKUP_DIR_LAST"
    _echo "      to: $BACKUP_DIR_CUR_TMP"
    $DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-instance-prepare-clone.sh "$BACKUP_DIR" "$HOST_NAME" "$BACKUP_DATE_TO_USE" "$DATE_PREPARE.tmp"
    _echo "    done."
else
    _error "Invalid preparation method: $PREPARATION_METHOD"
fi

_echo -n "  Removing flags and logs... "
rm -f $BACKUP_DIR_CUR_TMP/.done.*
rm -f $BACKUP_DIR_CUR_TMP/.log.*
rm -f $BACKUP_DIR_CUR_TMP/.prepar*
rm -f $BACKUP_DIR_CUR_TMP/.processing*
rm -f $BACKUP_DIR_CUR_TMP/.complete*
_echo "done."

_echo -n "  Moving to final location and setting flag... "
$DIR_APP_DRIVER_STORAGE/$BACKUP_DIR_STORAGE_DRIVER/host-backup-instance-prepare-move.sh "$BACKUP_DIR" "$HOST_NAME" "$DATE_PREPARE.tmp" "$DATE_PREPARE"
touch $BACKUP_DIR_CUR/$FLAG_PREPARED
_echo "done."



### Remove pid file
remove_pid_file



### Exit
exit 0
