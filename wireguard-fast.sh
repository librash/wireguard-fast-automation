#!/usr/bin/env bash
set -e

echo
if ! [[ $(id -u) = 0 ]]; then
  echo "Please run 'sudo ./install-wireguard.sh'" >&2
  exit 1
fi

read -e -p "Use VPN for *all* internet traffic? [y/n] " -i n ROUTE_ALL
if [[ ! $ROUTE_ALL = y* ]] && [[ ! $ROUTE_ALL = n* ]]; then
  echo Unknown response - must be y or n
  exit 1
fi

read -e -p "# of clients? [Betwen 1 and 253] " -i 5 NUM
read -e -p "Server hostname/IP? " -i $(curl -s ifconfig.me) SERVER

read -e -p "Specify VPN network address e.g 10.40.40.1-" SUBNET_IP
echo You enterned $SUBNET_IP
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
if [[ $SUBNET_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	oct1=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $1 }')
	oct2=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $2 }')
	oct3=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $3 }')
	oct4=$(echo ${SUBNET_IP} | tr "." " " | awk '{ print $4 }')
	SUBNET_IPADDRESS=$oct1.$oct2.$oct3.1
#	echo "Subnet Ipaddress is $SUBNET_IPADDRESS"
else
	echo "fail"
fi

echo "Updating system........"
apt-get update -y
echo "........system update done"

echo "Installing wireguard........"
apt-get install -qq wireguard zip
echo ".......wireguard installation done"

echo "Setting up system ip forwarding....."
if [ `sysctl net.ipv4.ip_forward -b` == 0 ]; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-sysctl.conf
  sysctl -w net.ipv4.ip_forward=1
fi
echo "......done"

echo "Generating server key......"
wg genkey | tee server.key | wg pubkey > server.pub
echo "......done"


INTER=$(ip -o -4 route show to default | awk '{print $5}')
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = $SUBNET_IPADDRESS/24
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTER -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTER -j MASQUERADE
ListenPort = 51820
PrivateKey = $(cat server.key)
EOF

systemctl start wg-quick@wg0
wg

# IP 1 is reserved for server
NUM=$(($NUM + 1))
for i in $(seq 2 $NUM); do . ./_add-client.sh $i $SUBNET_IPADDRESS; done

ufw allow 51820/udp
systemctl enable wg-quick@wg0

if [ $SUDO_USER ]; then user=$SUDO_USER
else user=$(whoami); fi
zip -rq clients clients
chown $user clients.zip

cat > add_client.sh << EOF
#!/usr/bin/env bash
SUBNET_IP=$SUBNET_IPADDRESS SERVER=$SERVER ROUTE_ALL=$ROUTE_ALL ./add-client.sh $1
EOF

if [ $SUDO_USER ]; then user=$SUDO_USER
else user=$(whoami); fi
chown -R $user add_client.sh
chmod u+x add_client.sh

echo 
echo Done. clients.tgz contains your client configuration files.
echo To add clients in the future run:
echo "   sudo ./add-client.sh NUMBER"
echo where NUMBER is the client number to create, which must be larger than $NUM

