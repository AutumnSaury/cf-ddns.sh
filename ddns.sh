#!/bin/bash
CFKEY=
CFUSER=
CFRECORD_TYPE=
CFTTL=
CFRECORD_NAME=()
CFZONE_NAME=
CFZONE_ID=
NET_DEVICE=

_sync()
{
for RECORD in ${CFRECORD_NAME[*]}
	do   
	RECORD=$RECORD.$CFZONE_NAME
	CFRECORD_ID=$(curl --connect-timeout 5 --retry 10 -s \
	        -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$RECORD" \
	        -H "X-Auth-Email: $CFUSER" \
	        -H "X-Auth-Key: $CFKEY" \
	        -H "Content-Type: application/json" | \
	        grep -Po '(?<="id":")[^"]*')
	curl -s --connect-timeout 5 --retry 10 \
	        -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
	        -H "X-Auth-Email: $CFUSER" \
	        -H "X-Auth-Key: $CFKEY" \
	        -H "Content-Type: application/json" \
	        --data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$RECORD\",\"content\":\"$CURRENT_IP\", \"ttl\":$CFTTL}" > /dev/null
	done
}

if [[ $1 = -f ]]; then
        if [[ -z $2 ]]; then
            FORCE=true
        else
            CURRENT_IP=$2
            _sync
            echo [$(date "+%Y-%m-%d %H:%M:%S")] Host\'s IP was manually synced to $CURRENT_IP
            exit 0
        fi
fi

if [[ $CFRECORD_TYPE = A ]]; then
	CURRENT_IP=$(curl -4 icanhazip.com)
	# CURRENT_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
        if [[ $? != 0 ]]; then
            echo "Error occured while getting IP, please retry later."
	        exit 1
        fi
elif [[ $CFRECORD_TYPE = AAAA ]]; then
        CURRENT_IP=$(ip -6 addr show dynamic dev $NET_DEVICE | grep inet6 | head -1 | awk -F '[ /]+' '{print $3}')
fi

if [[ -z $FORCE ]]; then
	CURRENT_RESOLVE=$(curl --connect-timeout 5 --retry 10 -s \
        -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=${CFRECORD_NAME[1]}.$CFZONE_NAME" \
        -H "X-Auth-Email: $CFUSER" \
        -H "X-Auth-Key: $CFKEY" \
        -H "Content-Type: application/json" | \
	grep -Po '(?<="content":")[^"]*')
    if [[ $CURRENT_RESOLVE = $CURRENT_IP ]]; then
            echo IP was not changed, exiting...
            exit 0 
    else
            _sync
            echo [$(date "+%Y-%m-%d %H:%M:%S")] Host\'s IP was synced to $CURRENT_IP
            exit 0
    fi
else
    _sync
    echo [$(date "+%Y-%m-%d %H:%M:%S")] Host\'s IP was forced to sync to $CURRENT_IP
    exit 0
fi
