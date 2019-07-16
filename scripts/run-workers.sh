#!/bin/bash

if [ -z "$1" ]; then
    echo "Please enter test name!"
    exit 1
fi

DOMAIN=$(basename $1)
JM_LOG='/root/jmeter-results/jmeter-run.log'
RESULTS_DIR='/root/jmeter-results/results'
CSV_DIR='/root/jm-csv'
TEST_PLAN='/root/TEST_PLAN.jmx'
truncate -s0 $JM_LOG

NAMESERVER='nameserver 8.8.8.8'

#echo $NAMESERVER > /etc/resolv.conf

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

[ -d "${CSV_DIR}" ] || mkdir -p ${CSV_DIR} 
[ ! -f ${CSV_DIR}/${DOMAIN}.csv ] || rm -f ${CSV_DIR}/${DOMAIN}.csv
[ ! -d "${RESULTS_DIR}/${DOMAIN}" ] || rm -rf ${RESULTS_DIR}/${DOMAIN}

echo "Starting Master Jmeter server" >> $JM_LOG
ulimit -n 999999

WORKERS="$(cat workers_list|xargs |sed -e "s/ /:1099,/g"):1099"
[ "x$WORKERS" == "x:1099" ] && WORKERS='' || WORKERS="-R $WORKERS"

bash /root/jmeter/bin/jmeter -Jserver.rmi.ssl.disable=true -n -r -t $TEST_PLAN -l ${CSV_DIR}/${DOMAIN}.csv -e -o ${RESULTS_DIR}/${DOMAIN} $WORKERS >> $JM_LOG

for i in $(cat /root/workers_list);
do
   iptables -D INPUT -s $i -j ACCEPT
   iptables -D OUTPUT -d $i -j ACCEPT
   IP_FOR_ALLOW=$(ip r g $i |awk -F 'src' '{print $2}'|xargs)
   ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=2 -n -f root@$i "sh -c 'iptables -D INPUT -s $IP_FOR_ALLOW -j ACCEPT;iptables -D OUTPUT -d $IP_FOR_ALLOW -j ACCEPT;/usr/bin/pkill java; /usr/bin/pkill jmeter > /dev/null 2>&1 &'"
   [ "x$?" == "x0" ] && echo "Remove iptables rules and stop java on $i [OK]" >> $JM_LOG || echo "Remove iptables rules and stop java on $i [FAILED]" >> $JM_LOG
done

exit 0
