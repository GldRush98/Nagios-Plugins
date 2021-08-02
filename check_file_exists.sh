#!/bin/sh
#
# Description: Plugin to verify if a file or directory exists
#

PROGNAME=`basename $0`

# parse command line args
t=$(getopt -o n --long negate -n "$PROGNAME" -- "$@")
[ $? != 0 ] && exit $?
eval set -- "$t"

negate=false
while :; do
	case "$1" in
	-n|--negate)
		negate=true
		;;
	--)
		shift
		break
		;;
	*)
		echo >&2 "$PROGRAM: Internal error: [$1] not recognized!"
		exit 3
		;;
	esac
shift
done

STATE=3
if [ "$1" = "" ]; then
	echo "Usage: $PROGRAM [-n] [file]"
	echo "Options:"
	echo "-n, --negate negate the result"
	exit $STATE
fi

fi

if [ -f "$1" ]; then
	$negate && STATE=2 || STATE=0
	echo "OK - \"$1\" Exists"
elif [ -d "$1" ]; then
	$negate && STATE=2 || STATE=0
	echo "OK - \"$1\" Exists (Directory)"
else
	$negate && STATE=0 || STATE=2
	echo "CRITICAL - \"$1\" NOT found!"
fi

exit $STATE