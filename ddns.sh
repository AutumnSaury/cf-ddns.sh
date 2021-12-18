#!/bin/bash

# CloudFlare API Key.
CFKEY=
# Email Address of your CloudFlare account.
CFUSER=
# Record type. A and AAAA is supported.
CFRECORD_TYPE=
# Suffix of your IPv6 address.
IPV6_SUFFIX=
# TTL of the record, 1 for auto.
CFTTL=
# Your subdomains.
CFRECORD_NAME=()
# Your domain, e.g. example.com.
CFZONE_NAME=
# Zone ID of your domain.
CFZONE_ID=
# Device name of your network card.
NET_DEVICE=

update() {
        for RECORD in ${CFRECORD_NAME[*]}; do
                RECORD=$RECORD.$CFZONE_NAME
                CFRECORD_ID=$(curl --connect-timeout 5 --retry 10 -s \
                        -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$RECORD" \
                        -H "X-Auth-Email: $CFUSER" \
                        -H "X-Auth-Key: $CFKEY" \
                        -H "Content-Type: application/json" |
                        grep -Po '(?<="id":")[^"]*')
                curl -s --connect-timeout 5 --retry 10 \
                        -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
                        -H "X-Auth-Email: $CFUSER" \
                        -H "X-Auth-Key: $CFKEY" \
                        -H "Content-Type: application/json" \
                        --data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$RECORD\",\"content\":\"$CURRENT_IP\", \"ttl\":$CFTTL}" >/dev/null
        done
}

if [[ $1 = -f ]]; then
        if [[ -z $2 ]]; then
                FORCE=true
        else
                CURRENT_IP=$2
                update
                echo [$(date "+%Y-%m-%d %H:%M:%S")] Host\'s IP was manually synced to $CURRENT_IP
                exit 0
        fi
fi

if [[ $CFRECORD_TYPE = A ]]; then
        CURRENT_IP=$(curl -4 icanhazip.com)
        if [[ $? != 0 ]]; then
                echo "An error occured while getting IP, please retry later."
                exit 1
        fi
elif [[ $CFRECORD_TYPE = AAAA ]]; then
        CURRENT_IP=$(ip -6 addr show dynamic dev $NET_DEVICE | grep $IPV6_SUFFIX | head -1 | awk -F '[ /]+' '{print $3}')
else
        echo "Unsupported record type."
fi

if [[ -z $FORCE ]]; then
        CURRENT_RESOLVE=$(curl --connect-timeout 5 --retry 10 -s \
                -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=${CFRECORD_NAME[0]}.$CFZONE_NAME" \
                -H "X-Auth-Email: $CFUSER" \
                -H "X-Auth-Key: $CFKEY" \
                -H "Content-Type: application/json" |\
                grep -Po '(?<="content":")[^"]*')
        if [[ $CURRENT_RESOLVE = $CURRENT_IP ]]; then
                echo IP was not changed, exiting...
                exit 0
        else
                update
                echo [$(date "+%Y-%m-%d %H:%M:%S")] Records\' contents were synced to $CURRENT_IP.
                exit 0
        fi
else
        update
        echo [$(date "+%Y-%m-%d %H:%M:%S")] Records\' contents were synced to $CURRENT_IP by force.
        exit 0
fi
