#!/bin/bash
#
# Usage:  finduser [OPTION] [STRING]
# Where:  Where OPTION could be any of the following
#         -s  <servername>
#         -u  <username>
#         -h  Display usage information
#
# Description:
#       User lookup utility. Mostly useful when doing account maintenance
#       for user deletion/mofification/password change.
#
# Background:
#       Common task/ticket request deals with finding user account from over
#       200+ Unix/Linux servers we managed for account maintenance ie. adding
#       sudo priviledges, password reset, account locking, etc.
#
#       finduser.sh will check for text file 'servers' for a list of servers it
#       will connect to. For convenience, setup ssh passwordless login on all
#       the servers before running the finduser script.
#
# Date  : 23rd May 2012
# Author: Gene Ordanza <geronimo.ordanza@fisglobal.com>
#

ARGS=$#
OPTSTRING="s:u:h"
FILE=/etc/passwd
SERVERLIST="/usr/local/bin/servers"
LOG=founduser.log
LOCALHOST=`hostname|tr '[:lower:]' '[:upper:]'`

function usage {
    echo "Usage: $(basename $0) [-s|-u|-h] <servername|username>"
    echo "Where:"
    echo "    -s <servername> Display all user account on a given server"
    echo "    -u <username>   Display user on all servers accessible from this host"
    echo "    -h Display this message"
    echo
    exit 1
}

function headings {
    printf "\nBASTION: $LOCALHOST " > $LOG
    printf "\nDATE   : `date +%m-%d-%Y`\n" >> $LOG
    printf "\n%-14s %-12s %-20s" 'SERVER' 'USERID' 'Description' >> $LOG
    printf "\n" >> $LOG
}


# Retrieve /etc/passwd from remote host listed in $SERVERLIST and then parsed
# them for userid and then write the result to $LOG. And then check the local
# passwd for the userid.

function multihost {

    local user=$1
    for host in $(cat $SERVERLIST); do
        scp $host:$FILE . &>/dev/null

        if grep -i $user passwd 1>/dev/null; then
            awk -v name="$user" -v host="$host" '
                BEGIN {FS=":"; IGNORECASE=1;}
                {if ($0 ~ name) {
                    printf "\n%-14s %-12s %-20s", host, $1, $5}}
            ' passwd >> $LOG
        fi
        echo "Checking host $host..."
    done

    if grep -i $user $FILE 1>/dev/null; then
        grep -i $user $FILE | awk -F: -v host=$LOCALHOST '
            {printf "\n%-14s %-12s %-20s", host, $1, $5}
        ' >> $LOG
    fi
    echo >> $LOG

    return
}

# Retrieve the /etc/passwd from the remote server (or localhost), and then call
# the 'parse' function to extract the login id and user name from the file.
function singlehost {
    local host=`echo $1|tr '[:lower:]' '[:upper:]'`
    local server="local"

    if [[ "$host" = "$LOCALHOST" ]]; then
        cp $FILE .
        parse "local" $host
        echo "checking host $host... "

    elif ping -c 2 $host > /dev/null 2>&1 ; then
        scp $host:$FILE . &>/dev/null
        parse "$host"
        echo "checking host $host... "
    else
        echo "$1 is not accessible..."
    fi
}

# This function will determined the hostname to pass to the parser function.
function parse {
    local host="$1"

    if [[ "$1" = "local" ]];then
        parser $LOCALHOST
    else
        parser $host
    fi
    rm -f passwd
}


# This is where the actual parsing happens.  It will extract the userid, user
# name from passwd file and write it (plus the hostname from parse() to $LOG.
function parser {
    local keyword="home"

    awk -F: -v host="$1" -v key="$keyword" '
        {if ($6 ~ key) {
            printf "\n%-14s %-12s %-20s", host, $1, $5}}
    ' passwd >> $LOG
    echo >> $LOG
}

# Required arguments: -s <servername> or -u <username>
# Display help/usage if used without any arguments.
function main {
    if [[ $ARGS -eq 0 ]]; then
        usage ; exit 1
    fi

    headings

    while getopts $OPTSTRING OPTION; do
        case ${OPTION} in
            s) singlehost ${OPTARG}; exit 0;;
            u) multihost  ${OPTARG}; exit 0;;
           \?) usage;;
            *) usage;;
        esac
    done
    exit 0
}

# Pass all command line arguments to the main function
main "$@"
