#!/bin/bash

while getopts u:d: option
do
 case "${option}"
 in
 u) URL=${OPTARG};;
 d) TEST_DURATION=${OPTARG};;
 *) echo "ERROR";;
 esac
done


DOMAIN=$(basename ${URL})
TEST_NAME=${DOMAIN}-$(date +"%d-%m-%Y_%Hh-%Mm-%Ss")
JM_LOG='/root/jmeter-results/jmeter-run.log'
RESULTS_DIR='/root/jmeter-results/results'
CSV_DIR='/root/jm-csv'
TEST_PLAN='/root/TEST_PLAN.jmx'
TEST_DURATION=$(( $TEST_DURATION*60 ))
truncate -s0 $JM_LOG

NAMESERVER='nameserver 8.8.8.8'

if [ "x$TEST_DURATION" == "x0" ]
then
    TEST_DURATION=$(grep 'ThreadGroup.duration' $TEST_PLAN |awk -v RS='>' -v FS='<' 'NR>1{print $1}'|xargs)
fi

echo "Check all remote workers..." >> $JM_LOG
/usr/sbin/jmenv-manager check &>> $JM_LOG

echo "Kill all master java processes..." >> $JM_LOG
/usr/bin/pkill java; /usr/bin/pkill jmeter;

for i in $(cat /root/workers_list;cat /root/workers_remote);
do
   iptables -I INPUT -s $i -j ACCEPT
   iptables -I OUTPUT -d $i -j ACCEPT
   IP_FOR_ALLOW=$(ip r g $i |awk -F 'src' '{print $2}'|xargs)
   ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=2 -n -f root@$i "sh -c 'echo $NAMESERVER > /etc/resolv.conf;iptables -I INPUT -s $IP_FOR_ALLOW -j ACCEPT;iptables -I OUTPUT -d $IP_FOR_ALLOW -j ACCEPT;/usr/bin/pkill java; /usr/bin/pkill jmeter; timeout ${TEST_DURATION} bash /root/jmeter/bin/jmeter-server -Jserver.rmi.ssl.disable=true -Djava.rmi.server.hostname=$i > /dev/null 2>&1 &'"
   [ "x$?" == "x0" ] && echo "Add iptables rules and starting jmeter-worker on $i [OK]" >> $JM_LOG || echo "Add iptables rules and starting jmeter-worker on $i [FAILED]" >> $JM_LOG
done

echo "Drop influx db jmeter"
curl -XPOST "http://influx:8086/query" --data-urlencode "q=DROP DATABASE jmeter"
echo "Creating new DB jmeter"
curl -XPOST "http://influx:8086/query" --data-urlencode "q=CREATE DATABASE \"jmeter\""

sleep 10

[ -d "${CSV_DIR}" ] || mkdir -p ${CSV_DIR}
[ ! -f ${CSV_DIR}/${TEST_NAME}.csv ] || rm -f ${CSV_DIR}/${TEST_NAME}.csv
[ ! -d "${RESULTS_DIR}/${TEST_NAME}" ] || rm -rf ${RESULTS_DIR}/${TEST_NAME}

echo "Starting Master Jmeter server" >> $JM_LOG
ulimit -n 999999

WORKERS="$(cat workers_list workers_remote|xargs |sed -e "s/ /:1099,/g"):1099"
[ "x$WORKERS" == "x:1099" ] && WORKERS='' || WORKERS="-R $WORKERS"

timeout $TEST_DURATION bash /root/jmeter/bin/jmeter -Jserver.rmi.ssl.disable=true -n -r -t $TEST_PLAN -l ${CSV_DIR}/${TEST_NAME}.csv -e $WORKERS >> $JM_LOG
echo 'Load test finished' >> $JM_LOG
echo 'Genering report...' >> $JM_LOG
sed -i '' -e '$ d' ${CSV_DIR}/${TEST_NAME}.csv
/root/jmeter/bin/jmeter -g ${CSV_DIR}/${TEST_NAME}.csv -o ${RESULTS_DIR}/${TEST_NAME} >> $JM_LOG
echo 'Genering report [DONE]' >> $JM_LOG

for i in $(cat /root/workers_list;cat /root/workers_remote);
do
   iptables -D INPUT -s $i -j ACCEPT
   iptables -D OUTPUT -d $i -j ACCEPT
   IP_FOR_ALLOW=$(ip r g $i |awk -F 'src' '{print $2}'|xargs)
   ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=2 -n -f root@$i "sh -c 'iptables -D INPUT -s $IP_FOR_ALLOW -j ACCEPT;iptables -D OUTPUT -d $IP_FOR_ALLOW -j ACCEPT;/usr/bin/pkill java; /usr/bin/pkill jmeter > /dev/null 2>&1 &'"
   [ "x$?" == "x0" ] && echo "Remove iptables rules and stop java on $i [OK]" >> $JM_LOG || echo "Remove iptables rules and stop java on $i [FAILED]" >> $JM_LOG
done

exit 0
