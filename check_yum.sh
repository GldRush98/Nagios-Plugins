#!/bin/bash

UPDATES=$(yum check-update --quiet -d 0 -e 0| grep '^[a-zA-Z0-9]' | wc -l)

if [ "$UPDATES" -gt "0" ]; then
	SECURITY_UPDATES=$(yum -C --security check-update |grep " needed for security")
	SECURITY_COUNT=$(echo $SECURITY_UPDATES|awk '{ print $1 }')
	if [ "$SECURITY_COUNT" == "No" ]; then
		echo "YUM WARNING: $UPDATES Non-Security Updates Available | security_updates_available=0 non_security_updates_available=$UPDATES total_updates_available=$UPDATES"
		exit 1
	else
		$NS_UPDATES=`expr $UPDATES - $SECURITY_COUNT`
		echo "YUM CRITICAL: $SECURITY_COUNT SECURITY Updates Available. $NS_UPDATES Non-Security Updates Available. | security_updates_available=$SECURITY_COUNT non_security_updates_available=$NS_UPDATES total_updates_available=$UPDATES"
		exit 2
	fi
fi

echo "YUM OK: System is up to date | security_updates_available=0 non_security_updates_available=0 total_updates_available=0"
exit 0