# WireGuard One-Touch (Ubuntu)

Two small scripts to stand up a WireGuard server on Ubuntu and generate client configs into your home directory. All tunables live in `vpn/wg-config.env` so you (or anyone using the repo) only edit one file.

## Files
- `vpn/wg-server-setup.sh` — installs WireGuard, enables forwarding/NAT, writes `/etc/wireguard/wg0.conf`, starts the service.
- `vpn/wg-mkclients.sh` — adds peers to `wg0` and writes client configs to `~/vpn/clients`.
- `vpn/wg-config.env.example` — copy to `vpn/wg-config.env` and adjust.

## Quick start (server)
1. Clone the repo and enter it.
2. `cp vpn/wg-config.env.example vpn/wg-config.env` then edit the values you want (port, subnet, optional public endpoint/DNS).
3. `sudo ./vpn/wg-server-setup.sh`
4. Open UDP `WG_PORT` (default 51820) in your VPS/cloud firewall if applicable.

## Make clients
- One-off names: `sudo ./vpn/wg-mkclients.sh phone laptop`
- Batch: `sudo ./vpn/wg-mkclients.sh --prefix user --count 3`

Outputs land in `~/vpn/clients/*.conf` for the user who ran the command (even when using sudo).

Import the `.conf` file in WireGuard for Windows/macOS/Linux/Android/iOS.

## Config knobs (`vpn/wg-config.env`)
- `WG_IF` — interface name (default `wg0`).
- `WG_NET_CIDR` / `WG_NET` — server address and subnet (default `10.66.66.1/24`).
- `WG_PORT` — UDP listen port (default `51820`).
- `VPN_NET` — base network for clients (default `10.66.66` → `10.66.66.x/32`).
- `DNS` — DNS server pushed to clients (default `1.1.1.1`).
- `SERVER_ENDPOINT` — optional public IP/DNS for clients; leave empty to auto-detect server IPv4.
- `CLIENT_ALLOWED_IPS` — what routes go through the tunnel (default `0.0.0.0/0` for full tunnel).
- `CLIENT_KEEPALIVE` — keepalive seconds (default `25`).

## Repo name idea
`wireguard-one-touch-ubuntu`

## Publish to GitHub (optional)
```bash
git init
git add .
git commit -m "Add WireGuard one-touch setup + client generator"
git remote add origin git@github.com:YOUR_USER/wireguard-one-touch-ubuntu.git
git push -u origin main
```
