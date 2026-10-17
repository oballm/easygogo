#!/usr/bin/env bash
# Ubuntu/Debian kernel/network tune. Does not change timezone.
# sudo bash kernel-optimize.sh
set -euo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "Run as root: sudo bash $0" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq iftop vim curl fail2ban systemd-timesyncd

systemctl enable --now fail2ban
timedatectl set-ntp true 2>/dev/null || true
systemctl enable --now systemd-timesyncd 2>/dev/null || true
systemctl restart systemd-timesyncd 2>/dev/null || true

LIMITS=/etc/security/limits.conf
ensure_limit() { grep -qxF "$1" "$LIMITS" 2>/dev/null || echo "$1" >> "$LIMITS"; }
ensure_limit "root soft nofile 65535"
ensure_limit "root hard nofile 65535"
ensure_limit "* soft nofile 65535"
ensure_limit "* hard nofile 65535"

cat > /etc/sysctl.d/99-proxy-tune.conf << 'SYSCTL'
vm.swappiness = 10
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
fs.file-max = 65535
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_syn_retries = 3
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 65536
net.ipv4.tcp_rmem = 4096 262144 67108864
net.ipv4.tcp_wmem = 4096 262144 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_ignore = 0
net.ipv4.conf.all.arp_ignore = 0
net.ipv4.conf.lo.arp_ignore = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
kernel.sysrq = 1
# net.ipv4.ip_forward = 1
# net.ipv6.conf.all.forwarding = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
SYSCTL

modprobe tcp_bbr 2>/dev/null || true
modprobe nf_conntrack 2>/dev/null || true
mkdir -p /etc/modules-load.d
echo nf_conntrack > /etc/modules-load.d/nf_conntrack.conf
echo tcp_bbr > /etc/modules-load.d/bbr.conf

sysctl --system >/dev/null

sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc \
  net.core.rmem_max vm.swappiness net.ipv4.tcp_slow_start_after_idle \
  net.netfilter.nf_conntrack_max fs.file-max 2>/dev/null || true
systemctl is-active fail2ban
grep -E 'nofile 65535' "$LIMITS" || true
echo Done
