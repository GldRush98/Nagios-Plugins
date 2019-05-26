#!/bin/sh
#Don't forget to turn off requiretty in visudo
PRX=`/usr/bin/sudo /usr/bin/vtysh -c  'show ip bgp summary' | grep $2 | /usr/bin/awk '{print $10}'`
if [ $PRX = 'Connect' ]
then
        echo "CRITICAL - Connect"
        exit 2
elif [ $PRX = 'Active' ]
then
        echo "CRITICAL - Active"
        exit 2
elif [ $PRX -lt $1 ]
then
        echo "WARNING - Prefix count below threshold. Prefixes - $PRX"
        exit 1
elif [ $PRX -ge $1 ]
then
        echo "OK - Pefixes $PRX|Prefixes=$PRX;"
        exit 0
elif [ $PRX = '' ]
then
        echo "CRITICAL - Blank Data"
        exit 2
else
        echo "CRITICAL - Missing Neighbor $2 $PRX"
        exit 2
fi
