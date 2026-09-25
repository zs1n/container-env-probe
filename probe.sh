#!/bin/sh
# container-env-probe v2 - read-only inventory of the container's own runtime boundary.
# Outbound: only the link-local probes below. No scanning, no tree walking, no credentials.
S() { echo; echo "===== $1 ====="; }

S IDENTITY
id 2>&1; echo "hostname=$(hostname 2>&1)"; echo "uname=$(uname -a 2>&1)"

S USERNS
echo "uid_map: $(cat /proc/self/uid_map 2>&1)"
echo "gid_map: $(cat /proc/self/gid_map 2>&1)"
echo "setgroups: $(cat /proc/self/setgroups 2>&1)"
for n in user pid net mnt ipc uts cgroup time; do echo "ns_$n=$(readlink /proc/self/ns/$n 2>&1)"; done
echo "selinux_self=$(cat /proc/self/attr/current 2>&1)"

S CONTAINERENV
cat /run/.containerenv 2>&1

S NOMAD_TASK_DIRS
for p in /alloc /local /secrets; do echo "--- $p"; ls -la "$p" 2>&1 | head -25; done

S HOSTS
cat /etc/hosts 2>&1
S RESOLV
cat /etc/resolv.conf 2>&1

S LISTENING_TCP4
cat /proc/net/tcp 2>&1
S LISTENING_TCP6
cat /proc/net/tcp6 2>&1
S LISTENING_UNIX
cat /proc/net/unix 2>&1

S POSITIVE_CONTROL_DNS
# Does name resolution work at all from here? Proves the configured link-local
# resolver is reachable. Ordinary container behaviour, no third-party probe.
echo "getent github.com -> $(getent hosts github.com 2>&1 | head -2)"
echo "getent metadata.google.internal -> $(getent hosts metadata.google.internal 2>&1 | head -2)"

S POSITIVE_CONTROL_LINKLOCAL_TCP
# Control for the IMDS negative: a DIFFERENT link-local address, the one this
# container is configured to talk to. Distinguishes "no route to 169.254/16"
# from "this one address is filtered".
curl -sS -o /dev/null --max-time 5 --connect-timeout 4 \
     -w "169.254.1.1:53 connect=%{http_code} t=%{time_connect}\n" http://169.254.1.1:53/ 2>&1
curl -sS -o /dev/null --max-time 5 --connect-timeout 4 \
     -w "169.254.1.1:80 connect=%{http_code} t=%{time_connect}\n" http://169.254.1.1/ 2>&1

S IMDS_REACHABILITY
# AUTHORISED SCOPE: one address, one port, index path only.
# Explicitly NOT requested: any token, any service-account path, any attribute.
curl -sS -o /dev/null --max-time 6 --connect-timeout 5 \
     -w "169.254.169.254:80 connect=%{http_code} t=%{time_connect}\n" http://169.254.169.254/ 2>&1
echo "--- index only ---"
curl -sS --max-time 6 --connect-timeout 5 -H 'Metadata-Flavor: Google' \
     -w "\n<<HTTP %{http_code}>>\n" http://169.254.169.254/computeMetadata/v1/ 2>&1 | head -40

S DONE
echo "probe v2 complete"
while true; do
  printf 'HTTP/1.1 200 OK\r\nContent-Length: 3\r\nContent-Type: text/plain\r\n\r\nok\n' | nc -l -p 80 >/dev/null 2>&1 || sleep 1
done
