#!/usr/bin/env bash
set -euo pipefail

# Placeholder exporter:
# - tails a firewall log source
# - extracts basic iptables-related counters
# - exposes metrics in Prometheus text format
# - parses lines containing iptables/UFW markers and increments counters by protocol
#
# Replace this with a robust service implementation for production.

LOG_FILE="/var/log/kern.log"
METRICS_FILE="/tmp/firewall_metrics.prom"
PORT="9100"

total_events=0
tcp_events=0
udp_events=0

write_metrics() {
  cat > "${METRICS_FILE}" <<EOF
# HELP iptables_total_events Total number of firewall events observed.
# TYPE iptables_total_events counter
iptables_total_events ${total_events}

# HELP iptables_protocol_events Total number of firewall events by protocol.
# TYPE iptables_protocol_events counter
iptables_protocol_events{protocol="tcp"} ${tcp_events}
iptables_protocol_events{protocol="udp"} ${udp_events}
EOF
}

serve_metrics() {
  while true; do
    {
      echo -ne "HTTP/1.1 200 OK\r\nContent-Type: text/plain; version=0.0.4\r\n\r\n"
      cat "${METRICS_FILE}"
    } | nc -l "${PORT}" -q 1
  done
}

tail_and_count() {
  touch "${LOG_FILE}"
  tail -Fn0 "${LOG_FILE}" | while read -r line; do
    if [[ "${line}" == *"iptables"* || "${line}" == *"UFW BLOCK"* ]]; then
      total_events=$((total_events + 1))

      if [[ "${line}" == *"PROTO=TCP"* ]]; then
        tcp_events=$((tcp_events + 1))
      elif [[ "${line}" == *"PROTO=UDP"* ]]; then
        udp_events=$((udp_events + 1))
      fi

      write_metrics
    fi
  done
}

write_metrics
serve_metrics &
tail_and_count
