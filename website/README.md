# CTMB Website

Official landing page for **Claude Token Monitor Bar (CTMB)** — served at
**https://ctmb.haogre.com**.

A single self-contained static page (no build step, no dependencies): `index.html`
plus the app screenshot in `assets/`. Warm Claude-brand aesthetic with automatic
light / dark mode.

## Structure

```
website/
├── index.html          # the whole site (inline CSS + JS)
├── assets/
│   ├── og-image-v2.png  # X / Open Graph social preview
│   └── screenshot.png   # app screenshot
├── nginx-ctmb.conf      # server block for the VPS
└── deploy.sh            # rsync the site to the VPS webroot
```

## Deploy

TLS is terminated by Cloudflare (proxied). The origin serves plain HTTP on :80.

```bash
CTMB_HOST=deploy@<ORIGIN_HOST> ./deploy.sh
```

`CTMB_HOST` is intentionally required and should be supplied through your
local shell environment or an SSH alias. Do not commit the origin address or
an administrative SSH username to this public repository.

On the server the site is served by the `ctmb.haogre.com` nginx server block
(`/etc/nginx/sites-enabled/ctmb`), mirroring the existing `zenlock` site.

### Cloudflare routing (one-time)

Public traffic reaches the origin through a **Cloudflare Tunnel** (`cloudflared`),
not a direct A record. The hostname must be added to both the tunnel ingress and
DNS:

```bash
# 1. add the ingress rule in /etc/cloudflared/config.yml, before the 404 catch-all:
#      - hostname: ctmb.haogre.com
#        service: http://localhost:80
systemctl restart cloudflared

# 2. point the DNS name at the tunnel (proxied CNAME → <tunnel>.cfargotunnel.com):
cloudflared tunnel route dns --overwrite-dns <TUNNEL_ID> ctmb.haogre.com
```

TLS is terminated at Cloudflare's edge; the tunnel carries plain HTTP to nginx.
