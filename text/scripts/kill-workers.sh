#/bin/bash

JM_LOG='/root/jmeter-results/jmeter-run.log'

truncate -s0 $JM_LOG
echo "STOP Test in progress..." >> $JM_LOG


for i in `ps aux |grep -E 'workers.sh|java'|grep -vE 'grep|kill-workers.sh' | awk '{print $2}'`;
do
   echo "STOP Jmeter master" >> $JM_LOG
   echo "Kill Java on Master"
   kill -9 $i;
done


for i in $(cat /root/workers_list;cat /root/workers_remote);
do
   iptables -D INPUT -s $i -j ACCEPT
   iptables -D OUTPUT -d $i -j ACCEPT
   IP_FOR_ALLOW=$(ip r g $i |awk -F 'src' '{print $2}'|xargs)
   ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=2 -n -f root@$i "sh -c 'iptables -D INPUT -s $IP_FOR_ALLOW -j ACCEPT;iptables -D OUTPUT -d $IP_FOR_ALLOW -j ACCEPT;/usr/bin/pkill java; /usr/bin/pkill jmeter > /dev/null 2>&1 &'"
   [ "x$?" == "x0" ] && echo "Remove iptables rules and stop java on $i [OK]" >> $JM_LOG || echo "Remove iptables rules and stop java on $i [FAILED]" >> $JM_LOG
done

echo "STOP Jmeter [OK]" >> $JM_LOG
exit 0
