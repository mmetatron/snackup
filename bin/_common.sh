#!/bin/sh



# Config file paths
CONFIG_FILE_DEFAULT="`dirname $0`/../conf/default.conf"
CONFIG_FILE_LOCAL="`dirname $0`/../conf/local.conf"



# Read the config files
. $CONFIG_FILE_DEFAULT
. $CONFIG_FILE_LOCAL



# Get quietness argument
if [ "$1" == '-q' ] || [ "$1" == '--quiet' ]; then
    VERBOSE_OUTPUT="no"
else
    VERBOSE_OUTPUT="yes"
fi



# Define output function
_echo() {
    if [ "$VERBOSE_OUTPUT" == "yes" ] || [ "$ERROR_OCCURED" == "yes" ]; then
	if [ "$1" == "-n" ]; then 
	    echo -n "$2"
	else
	    echo "$1"
	fi
    fi
}



# Inform about start time
_echo_start() {
    _echo "Starting at `date`"
}



# Inform about end time
_echo_stop() {
    _echo "Finishing at `date`"
}



# Get pid file
PID_FILE="$PID_DIR/`basename $0`.pid"

# Check for stale process
_echo -n "Writing own pid to lockfile $PID_FILE... "
if [ -e $PID_FILE ]; then
    echo "old pid file found - another backup transfer process exists?"
    OLDPID=`cat $PID_FILE`
    if [ "`psfind ^$OLDPID`" == "" ]; then
	echo "  Process with pid $OLDPID from stale pidfile $PID_FILE does not exist - removing"
	rm $PID_FILE
    elif [ "`psfind ^$OLDPID | grep transfer.sh`" == "" ]; then
	echo "  Process with pid $OLDPID is not a backup transfer process - removing stale pidfile"
	rm $PID_FILE
    else
	_echo "Yes, exiting..."
	exit 1
    fi
fi

# Put own pid into lock file
PID=$$
echo $PID > $PID_FILE
_echo "done."
