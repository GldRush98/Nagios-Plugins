#!/bin/sh
#Don't forget to turn off requiretty in visudo
PRX=`/usr/bin/sudo /usr/bin/vtysh -c  'show ip bgp summary' | grep $2 | /usr/bin/awk '{print $10}'`
if [ $PRX = 'Connect' ]
then
	echo "CRITICAL - Connect|Prefixes=0;"
	exit 2
elif [ $PRX = 'Active' ]
then
	echo "CRITICAL - Active|Prefixes=0;"
	exit 2
elif [ $PRX -lt $1 ]
then
	echo "WARNING - Prefix count below threshold ($1). Prefixes - $PRX|Prefixes=$PRX;"
	exit 1
elif [ $PRX -ge $1 ]
then
	echo "OK - Pefixes $PRX|Prefixes=$PRX;"
	exit 0
elif [ $PRX = '' ]
then
	echo "CRITICAL - Blank Data|Prefixes=0;"
	exit 2
else
	echo "CRITICAL - Missing Neighbor $2 $PRX|Prefixes=0;"
	exit 2
fi