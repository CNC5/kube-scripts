#!/usr/bin/bash

apt install wireguard

mkdir -p wg
wg genkey | tee wg/privatekey | wg pubkey > wg/publickey
