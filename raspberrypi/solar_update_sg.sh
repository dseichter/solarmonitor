#!/bin/bash

# Run this script every 1 minute

# IPv4
CURRENTIP=$(curl "http://fritz.box:49000/igdupnp/control/WANIPConn1" \
  -H "Content-Type: text/xml; charset="utf-8"" \
  -H "SoapAction:urn:schemas-upnp-org:service:WANIPConnection:1#GetExternalIPAddress" \
  -d "<?xml version='1.0' encoding='utf-8'?> <s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'> <s:Body> <u:GetExternalIPAddress xmlns:u='urn:schemas-upnp-org:service:WANIPConnection:1' /> </s:Body> </s:Envelope>" \
  -s | grep -Eo '\<[[:digit:]]{1,3}(\.[[:digit:]]{1,3}){3}\>')

# IPv6
IPv6=$(curl -s "http://fritz.box:49000/igdupnp/control/WANIPConn1" \
  -H "Content-Type: text/xml; charset="utf-8"" \
  -H "SoapAction:urn:schemas-upnp-org:service:WANIPConnection:1#X_AVM_DE_GetIPv6Prefix" \
  -d "<?xml version='1.0' encoding='utf-8' ?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'> <s:Body> <u:X_AVM_DE_GetIPv6Prefix xmlns:u='urn:schemas-upnp-org:service:WANIPConnection:1' />  </s:Body></s:Envelope>")
IPv6_PREFIX=$(echo ${IPv6} | grep -oPm1 "(?<=<NewIPv6Prefix>)[^<]+")
IPv6_RANGE=$(echo ${IPv6} | grep -oPm1 "(?<=<NewPrefixLength>)[^<]+")
IPv6=${IPv6_PREFIX}/${IPv6_RANGE}

# load old IP
OLDIP=$(cat /home/dseichter/currentip.txt)

if [ "$CURRENTIP" != "$OLDIP" ]; then

aws lambda invoke --function-name solar_updateSecurityGroup \
                  --cli-binary-format raw-in-base64-out \
                  --payload '{"current_ip": "'$CURRENTIP'", "current_ipv6": "'$IPv6'"}' \
                  solar_updateSecurityGroup.log

echo $CURRENTIP > /home/dseichter/currentip.txt

fi
