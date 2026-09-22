#!/usr/bin/bash
#By: Nick Last Modified: 8/15/2025
#Loops through every LetsEncrypt fullchain.pem file in the letsencrypt directory and checks that they're good.
#Get a warning ahead of time if a renewal is broken so you can fix it before it expires.
#Based on https://github.com/burgr033/check_local_cert_nagios
warning=25	#default number of days for warning threshold if thresholds not set
critical=7	#default number of days for critical threshold if thresholds not set
final=0		#final exit code
count=0		#number of pem files checked
errors=0	#number of non-ok pem files
output=""	#final output status message if any
#Check for passed in thresholds. Fairly basic, just looks for 2 cli args that are 2 numbers that appear sane
if [ -z ${1+x} ] || [ -z ${2+x} ]; then
	: #One of the thresholds wasn't set so do nothing (use defaults)
else	#LetsEncrypt never issues certs over 90 days, so don't accept ridiculous thresholds
	if [ "$1" -lt 100 ] && [ "$2" -lt 100 ] && [ "$1" -gt "$2" ]; then
		warning=$1
		critical=$2
	else
		echo "PLUGIN ALERT: Arguments must be sane integers. Using defaults ($warning $critical)"
	fi
fi
#Loop through the files, count errors, build output
for f in /etc/letsencrypt/live/*/fullchain.pem; do
	dest_date=`date --date="$(openssl x509 -in $f -noout -enddate | cut -d= -f 2)" --iso-8601`
	diff=$(( ($(date '+%s' -d "$dest_date") - $(date '+%s')) / 86400 ))
	count=$((count+1))
	if [ "$diff" -gt "$warning" ]; then
		this_exit=0
	elif [ "$diff" -gt "$critical" ]; then
		output="${output}\nWARNING - $f expires in $diff days."
                errors=$((errors+1))
		this_exit=1
	else
		output="${output}\nCRITICAL - $f expires in $diff days."
                errors=$((errors+1))
		this_exit=2
	fi
	#Change exit code if needed	
	if [ "$this_exit" -gt "$final" ]; then
		final=$this_exit
	fi	
done
#Check the final return value and return output values
if [ "$final" -eq 0 ]; then
	printf "OK: All $count fullchain.pem files are over $warning days from expiring"
fi
if [ "$final" -eq 1 ]; then
	printf "WARNING: $errors fullchain.pem files are expiring in less than $warning days: $output"
fi
if [ "$final" -eq 2 ]; then
	printf "CRITICAL: $errors fullchain.pem files are expiring soon, some in less than $critical days!!!: $output"
fi
exit $final
