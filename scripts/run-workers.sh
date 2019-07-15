#!/bin/bash

if [ -z "$1" ]; then
    echo "Please enter test name!"
    exit 1
fi

JM_LOG='/var/www/webroot/ROOT/jmeter-run.log'
truncate -s0 $JM_LOG

NAMESERVER='nameserver 8.8.8.8'

echo $NAMESERVER > /etc/resolv.conf

echo "Kill all master java processes..." >> $JM_LOG
/usr/bin/pkill java; /usr/bin/pkill jmeter;

for i in $(cat /root/workers_list); 
do 
   iptables -I INPUT -s $i -j ACCEPT
   iptables -I OUTPUT -d $i -j ACCEPT
   IP_FOR_ALLOW=$(ip r g $i |awk -F 'src' '{print $2}'|xargs)
   ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=2 -n -f root@$i "sh -c 'echo $NAMESERVER > /etc/resolv.conf;iptables -I INPUT -s $IP_FOR_ALLOW -j ACCEPT;iptables -I OUTPUT -d $IP_FOR_ALLOW -j ACCEPT;/usr/bin/pkill java; /usr/bin/pkill jmeter; bash /root/jmeter/bin/jmeter-server -Jserver.rmi.ssl.disable=true > /dev/null 2>&1 &'"
   [ "x$?" == "x0" ] && echo "Add iptables rules and starting jmeter-worker on $i [OK]" >> $JM_LOG || echo "Add iptables rules and starting jmeter-worker on $i [FAILED]" >> $JM_LOG
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

echo "Starting Master Jmeter server" >> $JM_LOG
ulimit -n 999999

WORKERS="$(cat workers_list|xargs |sed -e "s/ /:1099,/g"):1099"
[ "x$WORKERS" == "x:1099" ] && WORKERS='' || WORKERS="-R $WORKERS"

bash /root/jmeter/bin/jmeter -Jserver.rmi.ssl.disable=true -n -r -t /var/lib/nginx/$1/TEST_PLAN.jmx -l /var/lib/nginx/$1/TEST_OUTPUT1.csv -e -o /var/www/webroot/ROOT/results/$1 $WORKERS >> $JM_LOG

for i in $(cat /root/workers_list);
do
   iptables -D INPUT -s $i -j ACCEPT
   iptables -D OUTPUT -d $i -j ACCEPT
   IP_FOR_ALLOW=$(ip r g $i |awk -F 'src' '{print $2}'|xargs)
   ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=2 -n -f root@$i "sh -c 'iptables -D INPUT -s $IP_FOR_ALLOW -j ACCEPT;iptables -D OUTPUT -d $IP_FOR_ALLOW -j ACCEPT;/usr/bin/pkill java; /usr/bin/pkill jmeter > /dev/null 2>&1 &'"
   [ "x$?" == "x0" ] && echo "Remove iptables rules and stop java on $i [OK]" >> $JM_LOG || echo "Remove iptables rules and stop java on $i [FAILED]" >> $JM_LOG
done

exit 0
