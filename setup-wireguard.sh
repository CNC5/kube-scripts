#!/usr/bin/bash

printf "Node internal ip: "
read internal_ip
apt install -y curl
external_ip=$(curl ifconfig.me)
apt install -y wireguard


mkdir -p wg
private_key=$(wg genkey)
public_key=$(echo $private_key | wg pubkey)

echo $private_key > wg/privatekey
echo $public_key > wg/publickey

random_port=$((20000 + $RANDOM % 65536))
while ! ss -tulpn | grep $random_port
do
    echo "Port $random_port is busy, repicking"
    random_port=$((20000 + $RANDOM % 65536))
done

cat <<WG0 > /etc/wireguard/wg0.conf
# Interface
[Interface]
Address = $internal_ip
ListenPort = $random_port
PrivateKey = $private_key

# Peers

WG0

echo "Default config written"
echo " - pubkey: $public_key"
echo " - peer config:"
cat <<EOF
[Peer]
PublicKey = $public_key
Endpoint = $external_ip:$random_port
AllowedIPs = $internal_ip
#PersistentKeepalive = 25
EOF
