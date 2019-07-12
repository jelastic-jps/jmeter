#!/bin/bash

while getopts u:r:t:d:l:p:c: option
do
 case "${option}"
 in
 u) USERS_COUNT=${OPTARG};;
 r) RAMP_TIME=${OPTARG};;
 t) DURATION=${OPTARG};;
 d) DOMAIN=${OPTARG};;
 l) LINKS=${OPTARG};;
 p) PROTOCOL=${OPTARG};;
 c) CUSTOM=${OPTARG};;
 *) echo "ERROR";;
 esac
done

CONFIG="/root/TEST_PLAN.jmx"
TEMPLATE="/root/TEST_PLAN.template"

if [ ! -z "$CUSTOM" ]
then
    echo "$CUSTOM" > $CONFIG
    exit 0
fi

if [ ! -z "$LINKS" ]
then
    VAR1=""
    for url in $LINKS; do
    random_timer=($(shuf -i 60-1200 -n 1))
    vals=($url)
    prev=("$VAR1")
    VAR1=$(cat <<EOF
            ${prev[0]}
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="HTTP GET ${vals[0]}" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain"></stringProp>
          <stringProp name="HTTPSampler.port"></stringProp>
          <stringProp name="HTTPSampler.protocol"></stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">${vals[0]}</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.implementation">Java</stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
        <hashTree/>
        <ConstantTimer guiclass="ConstantTimerGui" testclass="ConstantTimer" testname="Constant Timer ${!url}" enabled="true">
          <stringProp name="ConstantTimer.delay">${random_timer[0]}</stringProp>
        </ConstantTimer>
        <hashTree/>
EOF
)

    done

    export VAR1

    perl -lpe 'print "$ENV{VAR1}" if $. == 100' $TEMPLATE > $CONFIG
else
    cp $TEMPLATE $CONFIG
fi

# Set users
USERS_COUNT=$(( $USERS_COUNT/$(grep -v "^$" /root/workers_list|wc -l) ))
[ "x$USERS_COUNT" != "x0" ] || USERS_COUNT=1
[ ! -n "$USERS_COUNT" ] || xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/ThreadGroup[@testname='Thread Group']/stringProp[@name='ThreadGroup.num_threads']" -v "$USERS_COUNT" $CONFIG

# Set Rumpup time
[ ! -n "$RAMP_TIME" ] || xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/ThreadGroup[@testname='Thread Group']/stringProp[@name='ThreadGroup.ramp_time']" -v "$RAMP_TIME" $CONFIG

# Set Test Duration
DURATION=$(( $DURATION*60 ))
[ ! -n "$DURATION" ] || xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/ThreadGroup[@testname='Thread Group']/stringProp[@name='ThreadGroup.duration']" -v "$DURATION" $CONFIG

# Set domain name
[ ! -n "$DOMAIN" ] || xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.domain']" -v "$DOMAIN" $CONFIG

# Set domain regexp
[ ! -n "$DOMAIN" ] || xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.embedded_url_re']" -v "(?i).*$DOMAIN.*" $CONFIG

# Set protocol
if [ "x${PROTOCOL^^}" == "xHTTPS" ]
then
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.port']" -v "443" $CONFIG
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.protocol']" -v "https" $CONFIG 
else
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.port']" -v "80" $CONFIG
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.protocol']" -v "http" $CONFIG
fi
