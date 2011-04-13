#!/bin/bash



# Config file paths
CONFIG_FILE_DEFAULT="`dirname $0`/../conf/default.conf"
CONFIG_FILE_LOCAL="`dirname $0`/../conf/local.conf"



# Read the config files
. $CONFIG_FILE_DEFAULT
. $CONFIG_FILE_LOCAL



# Get quietness argument
if [ "$1" == '-q' ] || [ "$1" == '--quiet' ]; then
    VERBOSE_OUTPUT="no"
    shift
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



### Inform about end time
_echo_stop() {
    _echo "Finishing at `date`"
}



### Main function - loop through hosts
loop_hosts() {

    # Check hosts file
    if [ ! -e $HOSTS_FILE ]; then
	echo "ERROR: Hosts file not found: $HOSTS_FILE"
	exit 1
    fi


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
    FINAL_RETURN_VALUE='0'
    #cat $HOSTS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | sed -e 's/\s\+/ /g'| while read HOST_LINE; do
    for i in `seq 1 $HOSTS_COUNT`; do

	### Parse hosts line
	HOST_LINE=`cat $HOSTS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | sed -e 's/\s\+/ /g' | head -n $i | tail -n 1`
	HOST_NAME=`echo $HOST_LINE | cut -d ' ' -f 1`
	IP_PORT=`echo $HOST_LINE | cut -d ' ' -f 2`
	IP=`echo $IP_PORT | cut -d ':' -f 1`

	### Check if port is given
	if [ "`echo $IP_PORT | grep ':'`" == "" ]; then
	    PORT=$DEFAULT_SSH_PORT
	elif [ "`echo $IP_PORT | grep -v ':\$'`" == "" ]; then
	    PORT=$DEFAULT_SSH_PORT
	else
	    PORT=`echo $IP_PORT | cut -d ':' -f 2`
	fi

	### Parse modules
	MODULES=$DEFAULT_RSYNC_MODULES
	SPECIFIC_MODULES=`echo $HOST_LINE | cut -d ' ' -f 3-`
	if [ "$SPECIFIC_MODULES" != "" ]; then
	    MODULES=$SPECIFIC_MODULES
	fi

	### Call callback function
	$HOST_CALLBACK
	RETURN_VALUE=$?

	if [ "$RETURN_VALUE" != "0" ]; then
	    FINAL_RETURN_VALUE=$RETURN_VALUE
	fi
    done

    ### Return final return value
    return $FINAL_RETURN_VALUE
}



### Main function - loop through routers
loop_routers() {

    # Check hosts file
    if [ ! -e $ROUTERS_FILE ]; then
	echo "ERROR: Routers file not found: $ROUTERS_FILE"
	exit 1
    fi


    # Get number of hosts to backup
    HOSTS_COUNT=`cat $ROUTERS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | grep -c .`
    RET_VAL=$?
    if [ "$RET_VAL" != "0" ]; then
	echo "ERROR: Unable to get number of routers to backup"
	exit 1
    fi
    if [ "$HOSTS_COUNT" -lt "1" ]; then
	echo "ERROR: No routers to backup?"
	exit 1
    fi


    # Loop through the config file and parse it
    FINAL_RETURN_VALUE='0'
    #cat $HOSTS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | sed -e 's/\s\+/ /g'| while read HOST_LINE; do
    for i in `seq 1 $HOSTS_COUNT`; do

	### Parse hosts line
	HOST_LINE=`cat $ROUTERS_FILE | grep -v '^\s*$' | grep -v '^\s*#' | sed -e 's/\s\+/ /g' | head -n $i | tail -n 1`
	HOST_NAME=`echo $HOST_LINE | cut -d ' ' -f 1`
	IP_PORT=`echo $HOST_LINE | cut -d ' ' -f 2`
	IP=`echo $IP_PORT | cut -d ':' -f 1`

	SSH_USERNAME=`echo $HOST_LINE | cut -d ' ' -f 3`
	SSH_PASSWORD=`echo $HOST_LINE | cut -d ' ' -f 4`

	### Check if port is given
	if [ "`echo $IP_PORT | grep ':'`" == "" ]; then
	    PORT=$DEFAULT_SSH_PORT
	elif [ "`echo $IP_PORT | grep -v ':\$'`" == "" ]; then
	    PORT=$DEFAULT_SSH_PORT
	else
	    PORT=`echo $IP_PORT | cut -d ':' -f 2`
	fi

	### Parse modules
	MODULES=$DEFAULT_ROUTER_FILES
	SPECIFIC_MODULES=`echo $HOST_LINE | cut -d ' ' -f 5-`
	if [ "$SPECIFIC_MODULES" != "" ]; then
	    MODULES=$SPECIFIC_MODULES
	fi

	### Call callback function
	$ROUTER_CALLBACK
	RETURN_VALUE=$?

	if [ "$RETURN_VALUE" != "0" ]; then
	    FINAL_RETURN_VALUE=$RETURN_VALUE
	fi
    done

    ### Return final return value
    return $FINAL_RETURN_VALUE
}



### Pid file removal
remove_pid_file() {
    rm -f $PID_FILE
}



### Check date format
check_date() {
    DATE_TO_CHECK="$1"
    RES=`echo "$DATE_TO_CHECK" | grep -c '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$' | cat`
    if [ "$RES" == "0" ]; then
	return 1
    else
	return 0
    fi
}



### Inform about end time
_error() {
    echo "ERROR: $1"
    remove_pid_file
    if [ "$2" != "" ]; then
	exit $2
    else
	exit 127
    fi
}



### Exit with message and zero status
_exit() {
    _echo "$1"
    remove_pid_file
    exit 0
}



################################################################################
### Pid file generation
################################################################################

### Check pid directory
if [ -e $PID_DIR ]; then
    if [ ! -d $PID_DIR ]; then
	echo "ERROR Pid directory is not a directory: $PID_DIR"
	exit 1
    fi
else
    mkdir $PID_DIR
fi


### Get pid file name
PID_FILE="$PID_DIR/`basename $0`.pid"


### Check for stale process
if [ -e $PID_FILE ]; then
    echo "WARNING: old pid file found - another backup transfer process exists?"
    OLDPID=`cat $PID_FILE`
    if [ "`psfind ^$OLDPID`" == "" ]; then
	echo "  Process with pid $OLDPID from stale pidfile $PID_FILE does not exist - removing"
	rm $PID_FILE
    #FIXME regex
    elif [ "`psfind ^$OLDPID | fgrep .sh`" == "" ]; then
	echo "  Process with pid $OLDPID is not a backup transfer process - removing stale pidfile"
	rm $PID_FILE
    else
	_echo "    Yes, exiting..."
	exit 1
    fi
fi


# Write own pid to file now
PID=$$
echo $PID > $PID_FILE

################################################################################
### END Pid file generation
################################################################################



################################################################################
### Date variables
################################################################################

DATE_TODAY=`date +'%Y-%m-%d'`
DATE_TOMORROW=`date --date='next day' +'%Y-%m-%d'`

################################################################################
### END Date variables
################################################################################



################################################################################
### Checks
################################################################################

### DIRs
if [ ! -e $INSTALL_DIR ]; then
    _error "Install directory does not exist: $INSTALL_DIR"
fi
if [ ! -d $INSTALL_DIR ]; then
    _error "Not a directory: $INSTALL_DIR"
fi

if [ ! -e $BACKUP_DIR ]; then
    _error "Backup directory does not exist: $BACKUP_DIR"
fi
if [ ! -d $BACKUP_DIR ]; then
    _error "Not a directory: $BACKUP_DIR"
fi

################################################################################
### END Checks
################################################################################
