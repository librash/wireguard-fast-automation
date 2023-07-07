#!/usr/bin/env bash
set -e

i=$1
SUNBET_IPADDRESS=$SUBNET_IPADDRESS
if [[ $ROUTE_ALL = y* ]]; then
  SUBNET=0.0.0.0/0
  DNS="DNS = 1.1.1.1, 1.0.0.1"
elif [[ $ROUTE_ALL = n* ]]; then
  SUBNET=$SUBNET_IPADDRESS/24
  DNS=""
fi

if [[ ! $SERVER ]]; then
  echo "Please set SERVER" >&2; exit 1
fi

if [[ ! $SUBNET ]]; then
  echo "Please set SUBNET" >&2; exit 1
fi

if [[ ! $i ]]; then
  echo "Please pass client number to create" >&2; exit 1
fi

if ! [[ $(id -u) = 0 ]]; then
  echo "Please run with sudo" >&2; exit 1
fi

mkdir -p clients


oct1=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $1 }')
oct2=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $2 }')
oct3=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $3 }')
oct4=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $4 }')
SUBNET_IP=$oct1.$oct2.$oct3
#echo "Subnet Ipaddress is $SUBNET_IP"

wg genkey | tee $i.key | wg pubkey > $i.pub
echo "[Interface]
PrivateKey = $(cat $i.key)
Address = $SUBNET_IP.$i/24
$DNS
[Peer]
PublicKey = $(cat server.pub)
Endpoint = $SERVER:51820
AllowedIPs = $SUBNET
PersistentKeepalive = 15
" > clients/$i.conf

wg set wg0 peer $(cat $i.pub) allowed-ips $SUBNET_IP.$i/32
wg-quick save wg0

if [ $SUDO_USER ]; then user=$SUDO_USER
else user=$(whoami); fi
chown -R $user clients
rm $i.{key,pub}

