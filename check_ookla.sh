#!/bin/bash
##################################
# A nagios plugin to monitor your internet speed
# This plugin uses the output of Ookla's speedtest CLI client (https://speedtest.net/apps/cli)
# Tested with speedtest CLI 1.1.1
# You must specify the full path to the speedtest binary on your system below.
# You can also change which speedtest server it uses by setting the server value below (usually you'll want this set to your closest/fastest server)
# All speed values are treated as Mbps.
# Note: The very first time the check is run a license acceptance message will break the output. This shouldn't happen again after the first run.
# Written by Nick Overstreet https://www.nickoverstreet.com/
# Last modified 12-15-2021
##################################

#This needs to be the full path to the speedtest binary
speedtest="/usr/local/ncpa/plugins/speedtest"
#Specify a speedtest server id. Usually you want the one closest to you. (found from ./speedtest --servers)
#You will want to pick the one that gives you the best/most consistent results.
#You can comment this out and have it auto-pick for you, but I don't recommend that as you will likely get inconsistent results that way.
#server="6907" #CTI Fiber

#Some default thresholds in case none are specified
down_warn=10
down_crit=5
up_warn=10
up_crit=5
script_name=`basename $0`

print_version() {
	echo "$script_name: Version 1.2 (C)2021, Nick Overstreet (https://www.nickoverstreet.com/)"
	echo "Speedtest binary: `sudo $speedtest --version | head -n 1` ($speedtest)"
}

print_help() {
	print_version
	echo ""
	echo "Description:"
	echo "$script_name is a Nagios plugin to check your internet speed."
	echo "It uses the Ookla speedtest cli program and parses its output."
	echo "All speeds are treated as Mbps."
	echo ""
	echo "Example call:"
	echo "./$script_name -w 250 -c 100 -W 250 -C 100"
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
	echo "ERROR - Speedtest binary not found at $speedtest"
	exit 3
fi


#Ok, on to the main business
#Check if the server variable is set, otherwise just run with auto-select
if [ -z ${server+x} ];then
	manual_server=""
else
	manual_server="--server-id=$server"
fi
#Note, speedtest cli needs to be run as root when headless due to a bug in Ookla's binary. I reported this to them but they ignored it and have not fixed the bug after several version. I suspect they likely don't want their binary used like this.
cli_output=`sudo $speedtest $manual_server --format=tsv --accept-license 2>&1`
cli_exit=$?
#Dummy data for testing so I don't have to wait for a speedtest to run every single time
#cli_output="CTI Fiber - Taylorville, IL	6907	0.501	0.144	0	117914450	117529470	425087912	422982398	https://www.speedtest.net/result/c/guidi	1"

#Uses the tab delimiter set by the --format switch and breaks the output apart in to the results array
IFS=$'\t' read -r -a results <<<"$cli_output"

#Array contents is as follows:
#0 Site Name - CTI Fiber - Taylorville, IL
#1 Site ID - 6907
#2 Latency - 0.501
#3 Jitter - 0.144
#4 Packet Loss % - 0
#5 Download bytes per second - 117914450
#6 Upload bytes per second - 117529470
#7 Download data size (bytes) - 425087912
#8 Upload data size (bytes) - 422982398
#9 Results URL - https://www.speedtest.net/result/c/guid
#10 Unknown return value added in CLI 1.1 - This was always a 1 when I was testing, so I am not sure what it is indicating and is not in the documentation any where.

#Check and make sure the array is the proper size which should mean the speedtest worked, if not try and output some useful information to see what went wrong
#11 should be the proper count, but 10  is also apparently possible if Ookla's results servers are failing to return a proper result URL
if [ "${#results[@]}" -ne "11" ] && [ "${#results[@]}" -ne "10" ]; then
	echo "UNKNOWN - SpeedTest results were bad (results array was wrong size)"
	echo "This is usually caused by your specified speedtest server going down or other speedtest.net problems"
	echo "CLI Output: $cli_output"
	echo "CLI Exit Code: $cli_exit"
	echo "Array variables: ${results[@]}"
	exit 3
fi

#Convert download and upload results in to Mbps, drop any fractions (rounding the bytes won't affect the Mbps really)
down_bytes=`echo ${results[5]} | xargs printf "%.*f\n" 0`
down=`echo $(( $down_bytes / 125000 ))`
up_bytes=`echo ${results[6]} | xargs printf "%.*f\n" 0`
up=`echo $(( $up_bytes / 125000 ))`

#Get the output set up with some performance data (easier to read it this way)
perfdata="| Download=${down}Mbps;$down_warn;$down_crit Upload=${up}Mbps;$up_warn;$up_crit"
output="Download: $down Mbps, Upload: $up Mbps $perfdata"
down_state=""
up_state=""
ok_state=""
exit_code=3

#Do checks, set the output and exit state
if [ "$down_warn" -ge "$down" ]; then
	down_state="WARNING (Download) - "
	exit_code=1
fi
if [ "$up_warn" -ge "$up" ]; then
	up_state="WARNING (Upload) - "
	exit_code=1
fi
if [ "$down_crit" -ge "$down" ]; then
	down_state="CRITICAL (Download) - "
	exit_code=2
fi
if [ "$up_crit" -ge "$up" ]; then
	up_state="CRITICAL (Upload) - "
	exit_code=2
fi
if [ "$up" -gt "$up_warn" ] && [ "$down" -gt "$down_warn" ]; then
	ok_state="OK - "
	exit_code=0
fi

#Finally send our output and exit with the appropriate code
echo "${down_state}${up_state}${ok_state} $output"
exit $exit_code
