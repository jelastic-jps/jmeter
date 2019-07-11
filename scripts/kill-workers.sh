#/bin/bash

JM_LOG='/var/www/webroot/ROOT/jmeter-run.log'

truncate -s0 $JM_LOG
echo "STOP Test in progress..." >> $JM_LOG


for i in `ps aux |grep -E 'workers.sh|java'|grep -vE 'grep|kill-workers.sh' | awk '{print $2}'`;
do
   echo "STOP Jmeter master" >> $JM_LOG
   echo "Kill Java on Master"
   kill -9 $i;
done


for i in $(cat /root/workers_list);
do
   echo "STOP Jmeter worker $i" >> $JM_LOG
   echo "Kill Java on $i"
   ssh -o StrictHostKeyChecking=no -n -f root@$i "sh -c '/usr/bin/pkill java; /usr/bin/pkill jmeter;'"
done

echo "STOP Jmeter [OK]" >> $JM_LOG
exit 0
