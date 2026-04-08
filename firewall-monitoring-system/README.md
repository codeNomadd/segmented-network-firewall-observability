# Segmented Network Infrastructure with Firewall Monitoring & Alerting

Enterprise-style VMware lab that simulates a perimeter firewall, segmented internal/DMZ zones, controlled service exposure, and security observability. The implementation combines iptables routing and policy enforcement with Prometheus/Grafana telemetry for operational and security monitoring.
This lab emphasizes network segmentation, controlled service exposure via DMZ, and integration of observability into the security layer.

The design models how infrastructure teams expose public services safely while protecting internal assets and maintaining measurable detection coverage.

## Architecture

```text
Internet/NAT network
        |
        v
VM1 Firewall/Gateway (172.16.198.128, 10.0.0.1, 10.0.1.1)
   |                         |
   v                         v
VM2 Internal Server      VM3 DMZ Web Server (nginx)

iptables logs -> exporter -> Prometheus (scrape + rule evaluation) -> Grafana (visualization + alerting)
```

- VM1 is the trust boundary and routing choke point between external, internal, and DMZ networks.
- VM1 performs Layer-3 routing, NAT, and stateful firewall enforcement between all network zones.
- VM2 is placed on the internal LAN and is not directly reachable from external sources.
- VM3 hosts the published web workload in the DMZ and is exposed through controlled DNAT only.
- Monitoring pipeline converts firewall telemetry into queryable signals for detection and response.

## Network Topology

| VM | Role | Interface / Network | IP / CIDR | Gateway |
|---|---|---|---|---|
| VM1 | Firewall / Gateway | External (NAT) | `172.16.198.128/24` | Upstream NAT |
| VM1 | Firewall / Gateway | Internal LAN | `10.0.0.1/24` | N/A |
| VM1 | Firewall / Gateway | DMZ | `10.0.1.1/24` | N/A |
| VM2 | Internal Server | Internal LAN | `10.0.0.2/24` | `10.0.0.1` |
| VM3 | DMZ Web Server | DMZ | `10.0.1.2/24` | `10.0.1.1` |

## Network Segmentation

- **Internal LAN (`10.0.0.0/24`):** trusted workloads; never directly exposed to external ingress.
- **DMZ (`10.0.1.0/24`):** controlled exposure zone for public-facing services.
- **External (`172.16.198.0/24`):** ingress/egress boundary through VM1.
- Segmentation objective is strict blast-radius control: public access terminates in DMZ, not in internal space.

## Firewall Configuration (VM1)

Default policy:

- `INPUT: DROP`
- `FORWARD: DROP`
- `OUTPUT: ACCEPT`

Enforcement model:

- Forwarding is enabled on VM1 to allow inter-network traffic routing between interfaces.
- Allow `ESTABLISHED,RELATED` stateful return traffic.
- Optional SSH management allowance to VM1.
- Allow `Internal -> Internet` and `DMZ -> Internet` egress through NAT.
- Allow `External -> DMZ` only on TCP `8080` (DNAT to `10.0.1.2:80`).
- Block `External -> Internal` completely.
- Block `DMZ -> Internal` by default.

Reference implementation is provided in `scripts/firewall_rules.sh`.

## Traffic Flow Scenarios

- **Internal -> Internet:** VM2 egress is forwarded out via VM1 and source-translated with MASQUERADE.
- **External -> DMZ:** inbound TCP `8080` to VM1 external IP is DNATed to VM3 nginx on `10.0.1.2:80`.
- **External -> Internal (blocked):** no forward rule exists from external to internal subnet; traffic is dropped by policy.
- **DMZ -> Internal (blocked):** no forwarding rule allows traffic from `10.0.1.0/24` to `10.0.0.0/24`, enforcing strict zone separation.

## NAT and DNAT Strategy

- **SNAT/MASQUERADE:** `10.0.0.0/24` and `10.0.1.0/24` egress is translated on VM1 external interface.
- **DNAT (service publishing):** only TCP `8080` is translated to DMZ web service.
- This pattern isolates public exposure to an explicit port/protocol path while preserving outbound connectivity for internal and DMZ hosts. This approach ensures that internal addressing is never exposed externally while still enabling controlled service publication.

## Service Deployment (VM3)

- Install and enable nginx on VM3 (`10.0.1.2`).
- Serve a minimal health/status page from the default web root.
- Access path: `http://172.16.198.128:8080`

In a production environment, this DMZ service would typically sit behind a reverse proxy or load balancer, with TLS termination and additional access controls applied.

## Monitoring and Alerting

Pipeline:

```text
iptables -> log stream -> exporter -> Prometheus -> Grafana
```

- Firewall logs are parsed by the exporter into Prometheus metrics.
- Prometheus scrapes exporter metrics and evaluates alert rules.
- Grafana dashboards surface event trends, protocol splits, and blocked-port concentration.
The monitoring layer provides visibility into firewall decisions rather than raw packet data, enabling lightweight anomaly detection.

Configured spike alert:

```promql
increase(iptables_total_events[5m]) > 500
```

This alert detects short-window deviations from baseline firewall activity, typically aligned with scanning bursts, brute-force noise, or policy drift.

## Operational Value

- Reduces mean-time-to-detect (MTTD) for abnormal network behavior at the perimeter.
- Delivers actionable firewall visibility without deep packet inspection overhead.
- Establishes a practical security-monitoring baseline for environments without full SIEM coverage.
- Demonstrates segmented-zone governance that maps to enterprise control objectives.

## Future Improvements

- Add Alertmanager routing and escalation policies (SOC/on-call integrations).
- Replace shell exporter with production service (Go/Python) and structured parsing.
- Introduce config management and immutable rollout for firewall policy changes.
- Add node/system telemetry from all VMs and correlate with firewall anomalies.
- Extend DMZ with reverse proxy + TLS termination + access logs enrichment.

## Design Summary

This project demonstrates how network segmentation, firewall policy enforcement, and observability can be combined into a cohesive infrastructure design.

It reflects a simplified but realistic model of enterprise perimeter security, where controlled exposure, isolation, and monitoring work together to reduce risk and improve operational awareness.
