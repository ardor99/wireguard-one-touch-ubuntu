#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/wg-config.env"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
else
  echo "[info] No ${CONFIG_FILE}, using built-in defaults. Copy wg-config.env.example to override."
fi

: "${WG_IF:=wg0}"
: "${WG_NET_CIDR:=10.66.66.1/24}"
: "${WG_NET:=10.66.66.0/24}"
: "${WG_PORT:=51820}"

WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IF}.conf"
SERVER_KEY="${WG_DIR}/server.key"
SERVER_PUB="${WG_DIR}/server.pub"

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run with sudo: sudo $0"
    exit 1
  fi
}

default_iface() { ip route | awk '/default/ {print $5; exit}'; }
server_ipv4() { ip -4 addr show dev "$(default_iface)" | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1; }

ensure_packages() {
  apt update
  apt upgrade -y
  apt install -y wireguard iptables
}

enable_forwarding() {
  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-wireguard.conf
  sysctl --system >/dev/null
}

ensure_keys() {
  mkdir -p "$WG_DIR"
  chmod 700 "$WG_DIR"

  if [[ ! -f "$SERVER_KEY" ]]; then
    wg genkey > "$SERVER_KEY"
    chmod 600 "$SERVER_KEY"
  fi

  if [[ ! -f "$SERVER_PUB" ]]; then
    wg pubkey < "$SERVER_KEY" > "$SERVER_PUB"
    chmod 644 "$SERVER_PUB"
  fi
}

write_config() {
  local ext_if
  ext_if="$(default_iface)"

  cat > "$WG_CONF" <<CONF
[Interface]
Address = ${WG_NET_CIDR}
ListenPort = ${WG_PORT}
PrivateKey = $(cat "$SERVER_KEY")

PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -m state --state RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -A POSTROUTING -s ${WG_NET} -o ${ext_if} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -m state --state RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s ${WG_NET} -o ${ext_if} -j MASQUERADE
CONF

  chmod 600 "$WG_CONF"
}

open_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    ufw allow "${WG_PORT}/udp" || true
    ufw reload || true
  fi
}

start_service() {
  systemctl enable --now "wg-quick@${WG_IF}"
}

main() {
  need_root
  ensure_packages
  enable_forwarding
  ensure_keys
  write_config
  open_firewall
  start_service

  echo
  echo "OK. WireGuard is up."
  echo "Server IP: $(server_ipv4)"
  echo "Port: ${WG_PORT}/udp"
  echo "Server public key:"
  cat "$SERVER_PUB"
  echo
  wg show
  echo
  echo "IMPORTANT: If your VPS provider has a firewall, open ${WG_PORT}/UDP there too."
  echo "Next: create clients with sudo ${SCRIPT_DIR}/wg-mkclients.sh <name>"
}

main
