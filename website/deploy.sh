#!/usr/bin/env bash
# Deploy the CTMB website to the VPS. TLS terminated by Cloudflare.
set -euo pipefail

# Defaults to the `dmit` SSH alias — an alias name gives nothing away, so it can
# live here while the origin address and login stay in ~/.ssh/config.
HOST="${CTMB_HOST:-dmit}"
WEBROOT="/var/www/ctmb"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ Ensuring webroot on $HOST"
ssh "$HOST" "mkdir -p $WEBROOT"

echo "→ Syncing site"
rsync -az --delete \
  --exclude 'deploy.sh' --exclude 'nginx-ctmb.conf' --exclude 'README.md' \
  "$DIR/" "$HOST:$WEBROOT/"

echo "→ Stamping sitemap lastmod = $(date +%F)"
ssh "$HOST" "sed -i 's#<lastmod>.*</lastmod>#<lastmod>$(date +%F)</lastmod>#' $WEBROOT/sitemap.xml"

echo "→ Installing nginx server block"
scp "$DIR/nginx-ctmb.conf" "$HOST:/etc/nginx/sites-available/ctmb"
ssh "$HOST" "ln -sf /etc/nginx/sites-available/ctmb /etc/nginx/sites-enabled/ctmb && nginx -t && systemctl reload nginx"

echo "✓ Deployed → https://ctmb.haogre.com"
