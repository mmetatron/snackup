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
BACKUP_DATES=`ls $BACKUP_DIR/$HOST_NAME | grep '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$' | sort -r`

# If none
if [ "$BACKUP_DATES" == "" ]; then
    echo "WARNING: No previous backup found, creating new dir"
    mkdir $BACKUP_DIR/$HOST_NAME/$DATE_PREPARE
    touch $BACKUP_DIR/$HOST_NAME/$DATE_PREPARE/$FLAG_PREPARED
    exit
fi

# Get latest complete
BACKUP_DATE_TO_USE=""
for BACKUP_DATE in $BACKUP_DATES; do
    if [ -e $BACKUP_DIR/$HOST_NAME/$BACKUP_DATE/$FLAG_COMPLETE ]; then
	BACKUP_DATE_TO_USE=$BACKUP_DATE
	break
    fi
done

# If no complete, signal error
if [ "$BACKUP_DATE_TO_USE" == "" ]; then
    _error "No complete backup to use for preparation"
fi



### Do copy now to .tmp
BACKUP_DIR_LAST="$BACKUP_DIR/$HOST_NAME/$BACKUP_DATE_TO_USE"
BACKUP_DIR_CUR_TMP="$BACKUP_DIR/$HOST_NAME/$DATE_PREPARE.tmp"
BACKUP_DIR_CUR="$BACKUP_DIR/$HOST_NAME/$DATE_PREPARE"

_echo "  Hard linking: "
_echo "    from: $BACKUP_DIR_LAST"
_echo "      to: $BACKUP_DIR_CUR_TMP"
ionice -c3 cp -al $BACKUP_DIR_LAST $BACKUP_DIR_CUR_TMP
_echo "    done."

_echo -n "  Removing flags and logs... "
rm -f $BACKUP_DIR_CUR_TMP/.done.*
rm -f $BACKUP_DIR_CUR_TMP/.log.*
rm -f $BACKUP_DIR_CUR_TMP/.prepar*
rm -f $BACKUP_DIR_CUR_TMP/.processing*
rm -f $BACKUP_DIR_CUR_TMP/.complete*
_echo "done."

_echo -n "  Moving to final location and setting flag... "
mv $BACKUP_DIR_CUR_TMP $BACKUP_DIR_CUR
touch $BACKUP_DIR_CUR/$FLAG_PREPARED
_echo "done."



### Remove pid file
remove_pid_file



### Exit
exit 0
