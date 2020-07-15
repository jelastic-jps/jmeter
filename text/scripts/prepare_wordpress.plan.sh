#!/bin/bash

while getopts u:r:t:w:t:d:l:p:c: option
do
 case "${option}"
 in
 u) USERS_COUNT=${OPTARG};;
 r) RAMP_TIME=${OPTARG};;
 t) DURATION=${OPTARG};;
 w) USERNAME=${OPTARG};;
 p) PASSWORD=${OPTARG};;
 d) URL=${OPTARG};;
 l) LINKS=${OPTARG};;
 *) echo "ERROR";;
 esac
done

CONFIG="/root/TEST_PLAN.jmx"
TEMPLATE="/root/TEST_PLAN-WP.template"

if [ ! -z "$LINKS" ]
then
    VAR1=""
    for url in $LINKS; do
    vals=($url)
    prev=("$VAR1")
    VAR1=$(cat <<EOF
            ${prev[0]}
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="HTTP GET $(echo ${vals[0]} | sed -e 's/\//>/g')" enabled="true">
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
EOF
)

    done

    export VAR1

    perl -lpe 'print "$ENV{VAR1}" if $. == 198' $TEMPLATE > $CONFIG
else
    cp $TEMPLATE $CONFIG
fi

# Set users
WORKERS_COUNT=$(grep -v "^$" /root/workers_*|wc -l)
USERS_PER_NODE=$(( $USERS_COUNT/$WORKERS_COUNT ))
[ $USERS_PER_NODE -gt 135 ] && { echo "Not enough workers nodes. Maximum users count per worker is 135. For running test with $USERS_COUNT you should have $(( $USERS_COUNT/135 )) nodes"; exit 1; }
USERS_COUNT=$USERS_PER_NODE
[ "x$USERS_COUNT" != "x0" ] || USERS_COUNT=1
[ ! -n "$USERS_COUNT" ] || xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/ThreadGroup[@testname='Thread Group']/stringProp[@name='ThreadGroup.num_threads']" -v "$USERS_COUNT" $CONFIG

# Set domain name
if [ -n "$URL" ]
then
    DOMAIN=$(basename "$URL")
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.domain']" -v "$DOMAIN" $CONFIG
    # Set domain regexp
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.embedded_url_re']" -v "(?i).*$DOMAIN.*" $CONFIG
fi

# Set Rumpup time
if [ -n "$RAMP_TIME" ]
then
    RAMP_TIME=$(( $RAMP_TIME*60 ))
    [ "x$RAMP_TIME" != "x0" ] || RAMP_TIME=1
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/ThreadGroup[@testname='Thread Group']/stringProp[@name='ThreadGroup.ramp_time']" -v "$RAMP_TIME" $CONFIG
fi

# Set Test Duration
if [ -n "$DURATION" ]
then
    DURATION=$(( $DURATION*60+300 ))
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/ThreadGroup[@testname='Thread Group']/stringProp[@name='ThreadGroup.duration']" -v "$DURATION" $CONFIG
fi

# Set protocol
PROTOCOL=$(echo $URL| sed -e 's,:.*,,g')
if [[ -n "$PROTOCOL" && "x${PROTOCOL^^}" == "xHTTPS" ]]
then
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.port']" -v "443" $CONFIG
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.protocol']" -v "https" $CONFIG
elif [[ -n "$PROTOCOL" && "x${PROTOCOL^^}" == "xHTTP" ]]
then
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.port']" -v "80" $CONFIG
    xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/ConfigTestElement[@testname='HTTP Request Defaults']/stringProp[@name='HTTPSampler.protocol']" -v "http" $CONFIG
fi


# set wordpress login
[ ! -n "$USERNAME" ] || { USERNAME+='${userNumber}'; xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/HTTPSamplerProxy/elementProp/collectionProp/elementProp[@name='log']/stringProp[@name='Argument.value']" -v "${USERNAME}" $CONFIG; }
# set wordpress password
[ ! -n "$PASSWORD" ] || xmlstarlet edit -L -u "/jmeterTestPlan/hashTree/hashTree/hashTree/HTTPSamplerProxy/elementProp/collectionProp/elementProp[@name='pwd']/stringProp[@name='Argument.value']" -v "${PASSWORD}" $CONFIG
