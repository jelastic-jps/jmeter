#!/bin/bash

if [ -z "$1" ]; then
    echo "Please enter test name!"
    exit 1
fi

JM_LOG='/var/www/webroot/ROOT/jmeter-run.log'

truncate -s0 $JM_LOG
echo "Kill all master java processes..." >> $JM_LOG
/usr/bin/pkill java; /usr/bin/pkill jmeter;

for i in $(cat /root/workers_list); 
do 
   echo "Starting jmeter-worker on $i" >> $JM_LOG
   echo "Run Java on $i"
   ssh -o StrictHostKeyChecking=no -n -f root@$i "sh -c '/usr/bin/pkill java; /usr/bin/pkill jmeter; bash /root/jmeter/bin/jmeter-server -Jserver.rmi.ssl.disable=true > /dev/null 2>&1 &'"
done

sleep 10

if [ ! -d /var/lib/nginx/$1 ]; then
    mkdir -p /var/lib/nginx/$1
fi

if [ -f /var/lib/nginx/$1/TEST_OUTPUT1.csv ]; then
    rm -f /var/lib/nginx/$1/TEST_OUTPUT1.csv
fi

if [ -d /var/www/webroot/ROOT/results/$1 ]; then
    rm -rf /var/www/webroot/ROOT/results/$1
fi

if [ -d /var/lib/nginx/$1/TEST_PLAN.jmx ]; then
   rm -f /var/lib/nginx/$1/TEST_PLAN.jmx
fi

cp /root/TEST_PLAN.jmx /var/lib/nginx/$1/TEST_PLAN.jmx

echo "Run Master"
echo "Starting Master Jmeter server" >> $JM_LOG
ulimit -n 999999

WORKERS="$(cat workers_list|xargs |sed -e "s/ /:1099,/g")"
[ "x$WORKERS" == "x" ] || WORKERS="-R $WORKERS"

bash /root/jmeter/bin/jmeter -Jserver.rmi.ssl.disable=true -n -r -t /var/lib/nginx/$1/TEST_PLAN.jmx -l /var/lib/nginx/$1/TEST_OUTPUT1.csv -e -o /var/www/webroot/ROOT/results/$1 $WORKERS >> $JM_LOG
exit 0
