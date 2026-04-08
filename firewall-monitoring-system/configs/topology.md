# Firewall Monitoring Lab Topology

## Mermaid Diagram

```mermaid
flowchart TB
    internet["External / NAT Network<br/>172.16.198.0/24"]

    fw["VM1 Firewall / Gateway<br/>eth0: 172.16.198.128<br/>eth1: 10.0.0.1<br/>eth2: 10.0.1.1"]
    vm2["VM2 Internal Server<br/>10.0.0.2/24<br/>GW: 10.0.0.1"]
    vm3["VM3 DMZ Web Server (nginx)<br/>10.0.1.2/24<br/>GW: 10.0.1.1"]

    exporter["iptables Exporter"]
    prom["Prometheus"]
    graf["Grafana"]

    internet -->|"Inbound TCP 8080"| fw
    fw -->|"DNAT 8080 -> 10.0.1.2:80"| vm3
    vm2 -->|"Egress (NAT)"| fw
    vm3 -->|"Egress (NAT)"| fw
    fw -->|"Outbound Internet"| internet

    fw -->|"iptables logs"| exporter
    exporter -->|"metrics"| prom
    prom -->|"dashboards + alerts"| graf

    internet -. "blocked to 10.0.0.0/24" .-> vm2
    vm3 -. "blocked to internal" .-> vm2
```

## ASCII Topology

```text
                External / NAT Network
                    172.16.198.0/24
                           |
                           | VM1 eth0: 172.16.198.128
                  +--------+--------+
                  | VM1 Firewall/GW |
                  |  iptables + NAT |
                  +----+--------+---+
                       |        |
       VM1 eth1: 10.0.0.1   VM1 eth2: 10.0.1.1
                       |        |
                   10.0.0.0/24  10.0.1.0/24
                       |        |
                 +-----+--+   +--+----------------+
                 | VM2    |   | VM3               |
                 |Internal|   |DMZ Web (nginx)    |
                 |10.0.0.2|   |10.0.1.2           |
                 +--------+   +--------------------+

Telemetry path:
iptables logs -> exporter -> Prometheus -> Grafana
```

## Policy Notes

- Allowed: `Internal -> Internet` and `DMZ -> Internet` through NAT on VM1.
- Allowed: `External -> DMZ` only on TCP `8080` via DNAT to `10.0.1.2:80`.
- Blocked: `External -> Internal` and `DMZ -> Internal`.
