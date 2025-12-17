# WireGuard One-Touch (Ubuntu)

Spin up a WireGuard server on Ubuntu and generate client configs with two scripts. All user-facing settings live in one file: `vpn/wg-config.env`.

## What’s inside
- `vpn/wg-server-setup.sh` — install WireGuard, enable forwarding/NAT, write `/etc/wireguard/wg0.conf`, start the service.
- `vpn/wg-mkclients.sh` — add peers and drop client configs into `~/vpn/clients` for the invoking user (even with sudo).
- `vpn/wg-config.env.example` — copy to `vpn/wg-config.env` and adjust your IP/port/DNS/routes.

## Fast setup (server)
```bash
cp vpn/wg-config.env.example vpn/wg-config.env
# edit vpn/wg-config.env with your public IP/DNS/port if needed
sudo ./vpn/wg-server-setup.sh
```

Then open UDP `WG_PORT` (default 51820) on any cloud firewall/security-group.

Firewall examples:
- UFW (Ubuntu): `sudo ufw allow 51820/udp && sudo ufw reload`
- Cloud firewall/SG: add an inbound rule UDP `WG_PORT` → your server.

## Make clients
```bash
sudo ./vpn/wg-mkclients.sh phone laptop          # specific names
sudo ./vpn/wg-mkclients.sh --prefix user --count 3  # user1, user2, user3
```
Client files appear in `~/vpn/clients/*.conf`. Import in WireGuard (Windows/macOS/Linux/Android/iOS) and hit Activate.

## Common tweaks (`vpn/wg-config.env`)
- `WG_PORT` — UDP port (default `51820`).
- `WG_NET_CIDR` / `WG_NET` — server IP + subnet (default `10.66.66.1/24`).
- `VPN_NET` — client base (default `10.66.66` → clients get `10.66.66.x/32`).
- `DNS` — DNS pushed to clients (default `1.1.1.1`).
- `SERVER_ENDPOINT` — set your public IP/DNS; leave blank to auto-detect.
- `CLIENT_ALLOWED_IPS` — `0.0.0.0/0` for full tunnel; set a subnet for split tunnel.
- `CLIENT_KEEPALIVE` — keepalive seconds (default `25`).

How to edit config:
```bash
cp vpn/wg-config.env.example vpn/wg-config.env
nano vpn/wg-config.env   # change PORT, SERVER_ENDPOINT, DNS, etc.
```

## Handy checks
```bash
sudo wg show               # peers and handshakes
sudo ss -lunp | grep 51820 # confirm UDP listen
```

## Suggested repo name
`wireguard-one-touch-ubuntu`
