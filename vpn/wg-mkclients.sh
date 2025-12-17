#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/wg-config.env"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

: "${WG_IF:=wg0}"
: "${VPN_NET:=10.66.66}"
: "${DNS:=1.1.1.1}"
: "${WG_PORT:=51820}"
: "${SERVER_ENDPOINT:=}"
: "${CLIENT_ALLOWED_IPS:=0.0.0.0/0}"
: "${CLIENT_KEEPALIVE:=25}"

WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IF}.conf"
SERVER_PUB="${WG_DIR}/server.pub"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
CLIENT_DIR="${TARGET_HOME}/vpn/clients"

usage() {
  echo "Usage:"
  echo "  sudo $0 name1 name2 name3 ..."
  echo "  sudo $0 --prefix NAME --count N"
  exit 1
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run with sudo."
    exit 1
  fi
}

default_iface() { ip route | awk '/default/ {print $5; exit}'; }
server_ipv4() { ip -4 addr show dev "$(default_iface)" | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1; }

ensure_ready() {
  [[ -f "$WG_CONF" ]] || { echo "Missing $WG_CONF. Run server setup first."; exit 1; }
  [[ -f "$SERVER_PUB" ]] || { echo "Missing $SERVER_PUB. Run server setup first."; exit 1; }
  wg show "$WG_IF" >/dev/null 2>&1 || { echo "Interface $WG_IF not up. Start it: sudo systemctl start wg-quick@${WG_IF}"; exit 1; }

  mkdir -p "$CLIENT_DIR"
  chmod 700 "$(dirname "$CLIENT_DIR")" "$CLIENT_DIR" || true
  chown -R "${TARGET_USER}:${TARGET_USER}" "$(dirname "$CLIENT_DIR")" || true
}

next_free_octet() {
  local used next
  used="$(grep -E 'AllowedIPs *= *'"${VPN_NET}"'\.' "$WG_CONF" 2>/dev/null \
    | sed -E 's/.*'"${VPN_NET}"'\.([0-9]+)\/32.*/\1/' \
    | sort -n | uniq || true)"

  next=2
  while echo "$used" | grep -qx "$next"; do
    next=$((next+1))
    [[ $next -lt 255 ]] || { echo "No free IPs left in ${VPN_NET}.0/24"; exit 1; }
  done
  echo "$next"
}

mk_client() {
  local name="$1" octet ip priv pub endpoint server_pub
  [[ -n "$name" ]] || { echo "Empty client name"; exit 1; }
  echo "$name" | grep -Eq '^[a-zA-Z0-9._-]+$' || { echo "Bad client name: $name (letters/numbers/._- only)"; exit 1; }

  if grep -q "### CLIENT ${name}" "$WG_CONF" 2>/dev/null; then
    echo "Client already exists: $name"
    return 0
  fi

  octet="$(next_free_octet)"
  ip="${VPN_NET}.${octet}"
  endpoint="${SERVER_ENDPOINT:-$(server_ipv4)}"
  server_pub="$(cat "$SERVER_PUB")"

  priv="${WG_DIR}/${name}.key"
  pub="${WG_DIR}/${name}.pub"

  wg genkey > "$priv"
  chmod 600 "$priv"
  wg pubkey < "$priv" > "$pub"
  chmod 644 "$pub"

  # apply live + persist in config
  wg set "$WG_IF" peer "$(cat "$pub")" allowed-ips "${ip}/32"

  cat >> "$WG_CONF" <<EOF

### CLIENT ${name}
[Peer]
PublicKey = $(cat "$pub")
AllowedIPs = ${ip}/32
EOF

  cat > "${CLIENT_DIR}/${name}.conf" <<EOF
[Interface]
PrivateKey = $(cat "$priv")
Address = ${ip}/32
DNS = ${DNS}

[Peer]
PublicKey = ${server_pub}
Endpoint = ${endpoint}:${WG_PORT}
AllowedIPs = ${CLIENT_ALLOWED_IPS}
PersistentKeepalive = ${CLIENT_KEEPALIVE}
EOF

  chown "${TARGET_USER}:${TARGET_USER}" "${CLIENT_DIR}/${name}.conf"
  chmod 600 "${CLIENT_DIR}/${name}.conf"

  echo "OK: ${name} -> ${CLIENT_DIR}/${name}.conf (IP ${ip})"
}

main() {
  need_root
  ensure_ready

  [[ $# -ge 1 ]] || usage

  if [[ "${1:-}" == "--prefix" ]]; then
    [[ "${2:-}" != "" && "${3:-}" == "--count" && "${4:-}" =~ ^[0-9]+$ ]] || usage
    local prefix="$2" count="$4" i
    for i in $(seq 1 "$count"); do
      mk_client "${prefix}${i}"
    done
  else
    local n
    for n in "$@"; do
      mk_client "$n"
    done
  fi

  echo
  echo "Client files:"
  ls -la "$CLIENT_DIR" || true
  echo
  wg show
}

main "$@"
