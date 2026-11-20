#!/bin/bash
cd "$(dirname "$0")" || exit 1
echo "http://localhost:30001"
echo "Ctrl+C でサーバーを停止します"
docker run --rm \
  -p 30001:80 \
  -v "$(pwd):/usr/share/caddy" \
  caddy:alpine 2>/dev/null
