# Network Design - VMware Segmented Firewall Lab

## Topology Diagram (ASCII)

```text
                     External / NAT Network
                        192.168.232.0/24
                               |
                               | VM1 eth0: 192.168.232.128/24
                     +---------+----------+
                     |  VM1 Firewall/GW   |
                     | iptables + routing |
                     +----+-----------+---+
                          |           |
      VM1 eth1: 10.0.0.1/24           | VM1 eth2: 10.0.1.1/24
                          |           |
                    10.0.0.0/24      10.0.1.0/24
                          |           |
                 +--------+--+     +--+----------------+
                 | VM2       |     | VM3               |
                 | Internal  |     | DMZ Web Server    |
                 | 10.0.0.2  |     | nginx 10.0.1.2    |
                 +-----------+     +--------------------+
```

## IP Addressing Table

| Component | Role | Network | IP / CIDR | Default Gateway |
|---|---|---|---|---|
| VM1 `eth0` | External uplink | NAT/External | `192.168.232.128/24` | Upstream NAT |
| VM1 `eth1` | Internal gateway | Internal LAN | `10.0.0.1/24` | N/A |
| VM1 `eth2` | DMZ gateway | DMZ | `10.0.1.1/24` | N/A |
| VM2 | Internal server | Internal LAN | `10.0.0.2/24` | `10.0.0.1` |
| VM3 | DMZ web server | DMZ | `10.0.1.2/24` | `10.0.1.1` |

## Interface Mapping

- VM1 `eth0` -> external/NAT segment (`192.168.232.128/24`)
- VM1 `eth1` -> internal segment gateway (`10.0.0.1/24`)
- VM1 `eth2` -> DMZ segment gateway (`10.0.1.1/24`)
- VM2 primary NIC -> VM1 `eth1` segment
- VM3 primary NIC -> VM1 `eth2` segment

## Traffic Flow Model

- **Internal to Internet:** VM2 traffic routes to VM1 (`10.0.0.1`) and exits through `eth0` with MASQUERADE.
- **DMZ to Internet:** VM3 traffic routes to VM1 (`10.0.1.1`) and exits through `eth0` with MASQUERADE.
- **External to DMZ service:** inbound TCP `8080` on VM1 external IP is DNATed to `10.0.1.2:80`.
- **External to Internal:** denied by default forward policy and explicit deny posture.
- **DMZ to Internal:** denied by default (no allow rule), enforcing lateral movement restrictions.
