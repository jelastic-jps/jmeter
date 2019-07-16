#!/bin/bash

MEM_FOR_HEAP=$(( $(free -m|awk '/^Mem:/{print $2}')*70/100 ))
: "${HEAP:="-Xms${MEM_FOR_HEAP}m -Xmx${MEM_FOR_HEAP}m -XX:MaxMetaspaceSize=256m"}"
