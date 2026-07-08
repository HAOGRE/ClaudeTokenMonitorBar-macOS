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
│   └── screenshot.png   # app screenshot
├── nginx-ctmb.conf      # server block for the VPS
└── deploy.sh            # rsync the site to the VPS webroot
```

## Deploy

TLS is terminated by Cloudflare (proxied). The origin serves plain HTTP on :80.

```bash
./deploy.sh                 # rsync to root@202.61.75.240:/var/www/ctmb
```

On the server the site is served by the `ctmb.haogre.com` nginx server block
(`/etc/nginx/sites-enabled/ctmb`), mirroring the existing `zenlock` site.
