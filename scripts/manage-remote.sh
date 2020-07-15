#!/bin/bash

var=$1

if [ -z "$var" ]
then
      HostersToRemove=$(/usr/sbin/jmenv-manager list |sed 's/http/\nhttp/g'|grep ^http|xargs)
else
      HostersToRemove=$(/usr/sbin/jmenv-manager list |grep -vE "$(echo $var | sed 's/http/\nhttp/g'|sed -e 's|^[^/]*//||' -e 's|^www\.||' -e 's|/.*$||'|xargs|awk '{$1=$1}1' OFS="|")"|sed 's/http/\nhttp/g'|grep ^http|xargs)
fi

for appURL in $HostersToRemove; do
    /usr/sbin/jmenv-manager delete --url $appURL
done

IFS=';' read -ra ADDR <<< "$var"
for i in "${ADDR[@]}"; do
    appURL=$(echo $i |awk '{print $1}'|xargs)
    TOKEN=$(echo $i |awk '{print $2}'|xargs)
    /usr/sbin/jmenv-manager add --url $appURL --token $TOKEN
done
