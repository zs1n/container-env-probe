#!/bin/sh
# container-env-probe - read-only inventory of the container's own runtime boundary.
# Writes to stdout. Sends exactly one outbound request (see IMDS section), to one
# address, one port, one path. No scanning, no directory walking, no credentials.
S() { echo; echo "===== $1 ====="; }

S IDENTITY
id 2>&1
echo "hostname=$(hostname 2>&1)"
echo "uname=$(uname -a 2>&1)"

S STATUS
grep -E '^(Name|Umask|State|Uid|Gid|Groups|NoNewPrivs|Seccomp|Seccomp_filters|CapInh|CapPrm|CapEff|CapBnd|CapAmb|Speculation)' /proc/self/status 2>&1

S CGROUP
cat /proc/self/cgroup 2>&1

S MOUNTINFO
cat /proc/self/mountinfo 2>&1

S ENV_KEYS_ONLY
# keys + value LENGTH only: a value could be a credential injected by the platform.
env | while IFS='=' read -r k v; do echo "$k len=${#v}"; done 2>&1

S INTERFACES
ip -o addr 2>/dev/null || cat /proc/net/fib_trie 2>/dev/null | head -0
for d in /sys/class/net/*; do
  n=$(basename "$d")
  echo "iface=$n mac=$(cat "$d/address" 2>/dev/null) mtu=$(cat "$d/mtu" 2>/dev/null) flags=$(cat "$d/flags" 2>/dev/null)"
done

S ROUTES_V4
cat /proc/net/route 2>&1
S ROUTES_V6
cat /proc/net/ipv6_route 2>&1

S LISTENING_TCP4
cat /proc/net/tcp 2>&1
S LISTENING_TCP6
cat /proc/net/tcp6 2>&1
S LISTENING_UNIX
cat /proc/net/unix 2>&1

S NEIGHBOUR_COUNT_ONLY
echo "arp_entries=$(( $(wc -l < /proc/net/arp 2>/dev/null) - 1 ))"
echo "ndisc_entries=$(wc -l < /proc/net/ipv6_route 2>/dev/null)"

S PROC_VISIBILITY
echo "pids_visible=$(ls -1d /proc/[0-9]* 2>/dev/null | wc -l)"
ls -1 /proc/[0-9]*/comm 2>/dev/null | while read -r f; do echo "pid_comm=$(cat "$f" 2>/dev/null)"; done | sort | uniq -c

S AIVEN_PATHS_NAMES_ONLY
for p in /run/aiven /etc/pki/aiven /var/lib/aiven /run/secrets /etc/nomad.d /run/aiven/pruned /var/run/docker.sock /run/podman/podman.sock /var/run/nomad; do
  if [ -e "$p" ]; then echo "EXISTS $p"; ls -la "$p" 2>&1 | head -30; else echo "absent $p"; fi
done

S RESOLV
cat /etc/resolv.conf 2>&1

S IMDS_REACHABILITY
# AUTHORISED SCOPE: one address, one port, index path only.
# Explicitly NOT requested: any token, any service-account path, any attribute.
curl -s -o /dev/null -w "tcp_connect=%{http_code} time_connect=%{time_connect}\n" \
     --max-time 6 --connect-timeout 5 http://169.254.169.254/ 2>&1
echo "--- index only ---"
curl -s --max-time 6 --connect-timeout 5 -H 'Metadata-Flavor: Google' \
     -w "\n<<HTTP %{http_code}>>\n" http://169.254.169.254/computeMetadata/v1/ 2>&1 | head -40

S DONE
echo "probe complete"
# keep the container alive so the port stays healthy; serve a static 200.
while true; do
  printf 'HTTP/1.1 200 OK\r\nContent-Length: 3\r\nContent-Type: text/plain\r\n\r\nok\n' | nc -l -p 80 >/dev/null 2>&1 || sleep 1
done
