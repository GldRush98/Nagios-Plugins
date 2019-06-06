#!/bin/bash
##################################
# A nagios plugin to check speed.
# This plugin uses the output of speedtest.py from sivel (https://github.com/sivel/speedtest-cli)
# You must specify the full path to speedtest.py on your system below.
# You can also change which speedtest server it uses by setting the server value below.
# Based off of speedtest.py 2.1.1 - So if anything changes in newer version, this program may break.
# All speed values are treated as Mbps.
# Written by Nick Overstreet who knows very little about bash, so please forgive any wtf's
# Last modified 5-26-2019
##################################

#This needs to be the FULL path to the speedtest program
speedtest="/usr/local/nagios/libexec/speedtest.py"
#Specify a speedtest server id. Usually you want the one closest to you. (found from speedtest.py --list | more)
server="6907" #CTI Fiber

#Some default thresholds in case none are specified
down_warn=10
down_crit=5
up_warn=10
up_crit=5

PROGNAME=`basename $0`
VERSION="Version 1.0"
AUTHOR="(C)2019, Nick Overstreet (https://www.nickoverstreet.com/)"

print_version() {
	echo "Program: $VERSION $AUTHOR"
	echo "Speedtest: `$speedtest --version | head -n 1` ($speedtest)"
}

print_help() {
	print_version
	echo ""
	echo "Description:"
	echo "$PROGNAME is a Nagios plugin to check your internet speed."
	echo "It uses the speedtest.py program and parses its output."
	echo "All speeds are treated as Mbps."
	echo ""
	echo "Example call:"
	echo "./$PROGNAME -w 250 -c 100 -W 250 -C 100"
	echo ""
	echo "Options:"
	echo "  -w)"
	echo "    Download warning threshold. Default is: $down_warn"	
	echo "  -c)"
	echo "    Download critical threshold. Default is: $down_crit"
	echo "  -W)"
	echo "    Upload warning threshold. Default is: $up_warn"
	echo "  -C)"
	echo "    Upload critical threshold. Default is: $up_crit"
	echo "  -v)"
	echo "    Prints program version information."
	echo "  -h)"
	echo "    Prints this help information."
	exit 3
}

while test -n "$1"; do
    case "$1" in
        -h)
            print_help
            exit 3
            ;;
        -v)
	    print_version
            exit 3
            ;;
        -w)
            down_warn=$2
            shift
            ;;
        -c)
            down_crit=$2
            shift
            ;;
        -W)
            up_warn=$2
            shift
            ;;
        -C)
            up_crit=$2
            shift
            ;;
        *)
            echo "ERROR - Unknown argument: $1"
            print_help
            exit 3
            ;;
    esac
    shift
done

#Sanity checks
if [ "$down_crit" -ge "$down_warn" ];then
	echo "ERROR - Download critical value ($down_crit) must be lower than download warning value ($down_warn)!"
	exit 3
fi
if [ "$up_crit" -ge "$up_warn" ];then
	echo "ERROR - Upload critical value ($up_crit) must be lower than upload warning value ($up_warn)!"
	exit 3
fi

if [ ! -f "$speedtest" ]; then
	echo "ERROR - Speed test program not found at $speedtest"
	exit 3
fi


#Ok, on to the main business
cli_output=`$speedtest --single --server $server --csv --csv-delimiter !`
#Dummy data for testing so I don't have to wait for a speedtest to run every single time
#cli_output="6907!CTI Fiber!Taylorville, IL!2019-05-26T02:47:49.355522Z!1.0546901201974928!2.706!359240524.80328125!173436942.64836556!!72.9.120.187"

#Uses the delimiter ! set above and breaks the output out in to the results array
IFS=! read -r -a results <<<"$cli_output"

#Array contents is as follows:
#0 Site ID - 6907
#1 Provider - CTI Fiber
#2 Location - Taylorville, IL
#3 Date - 2019-05-26T02:47:49.355522Z
#4 Distance-KM - 1.0546901201974928
#5 Ping - 2.706
#6 Download - 359240524.80328125
#7 Upload - 173436942.64836556
#8 Results URL - 
#9 IP Address - 72.9.120.187
#10 (blank line)

#Check and make sure the array is the proper size which should mean the speedtest worked
if [ "${#results[@]}" -ne "10" ]; then
	echo "UNKNOWN - SpeedTest results were bad"
	echo "CLI Output: $cli_output"
	echo "Array: ${results[@]}"
	exit 3
fi

#Convert download and upload results in to Mbps, drop any fractions (rounding the bits won't affect the Mbps really)
down_bits=`echo ${results[6]} | xargs printf "%.*f\n" 0`
down=`echo $(( $down_bits / 1024 / 1024 ))`
up_bits=`echo ${results[7]} | xargs printf "%.*f\n" 0`
up=`echo $(( $up_bits / 1024 / 1024 ))`

#Get the output set up with some performance data
perfdata="| Download=$down;$down_warn;$down_crit Upload=$up;$up_warn;$up_crit"
output="Download: $down Mbps, Upload: $up Mbps $perfdata"
state=0

#Do checks and set state if needed
if [ "$down_warn" -ge "$down" ]; then
	state=1
fi
if [ "$up_warn" -ge "$up" ]; then
	state=1
fi
if [ "$down_crit" -ge "$down" ]; then
	state=2
fi
if [ "$up_crit" -ge "$up" ]; then
	state=2
fi

#Check the state, send the output, and exit with the appropriate code
if [ "$state" = 2 ];then
	echo "CRITICAL - $output"
	exit 2 

  elif [ "$state" = 1 ];then
	echo "WARNING - $output"
	exit 1

  else
	echo "OK - $output"
	exit 0
fi

