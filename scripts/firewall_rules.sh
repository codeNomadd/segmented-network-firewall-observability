#!/usr/bin/env bash
set -euo pipefail

# Enterprise-style firewall policy for VM1
# Interfaces and addressing (exact lab values):
# - eth0: external NAT network 192.168.232.128/24
# - eth1: internal LAN gateway 10.0.0.1/24
# - eth2: DMZ gateway 10.0.1.1/24
#
# Published service:
# - External TCP/8080 -> DNAT to 10.0.1.2:80 (VM3 nginx)

EXT_IF="eth0"
INT_IF="eth1"
DMZ_IF="eth2"

EXT_IP="192.168.232.128"
INT_NET="10.0.0.0/24"
DMZ_NET="10.0.1.0/24"
DMZ_WEB_IP="10.0.1.2"

echo "[*] Enabling IPv4 forwarding"
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[*] Flushing existing iptables rules"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

echo "[*] Setting default policies"
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

echo "[*] Allowing loopback and stateful return traffic"
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "[*] Optional management access (SSH to firewall)"
iptables -A INPUT -i "${EXT_IF}" -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

echo "[*] Allowing internal and DMZ outbound forwarding"
iptables -A FORWARD -i "${INT_IF}" -o "${EXT_IF}" -s "${INT_NET}" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i "${DMZ_IF}" -o "${EXT_IF}" -s "${DMZ_NET}" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

echo "[*] Publishing DMZ web service via DNAT (external:8080 -> 10.0.1.2:80)"
iptables -t nat -A PREROUTING -i "${EXT_IF}" -d "${EXT_IP}" -p tcp --dport 8080 -j DNAT --to-destination "${DMZ_WEB_IP}:80"
iptables -A FORWARD -i "${EXT_IF}" -o "${DMZ_IF}" -p tcp -d "${DMZ_WEB_IP}" --dport 80 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

echo "[*] Enabling outbound source NAT (MASQUERADE)"
iptables -t nat -A POSTROUTING -o "${EXT_IF}" -s "${INT_NET}" -j MASQUERADE
iptables -t nat -A POSTROUTING -o "${EXT_IF}" -s "${DMZ_NET}" -j MASQUERADE

echo "[*] Enforcing segmentation controls"
# Block external -> internal completely
iptables -A FORWARD -i "${EXT_IF}" -o "${INT_IF}" -j DROP
# Block DMZ -> internal by default
iptables -A FORWARD -i "${DMZ_IF}" -o "${INT_IF}" -j DROP

echo "[*] Firewall rules applied successfully"
iptables -S
echo "[*] NAT table:"
iptables -t nat -S
