#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-opencloud}"
IMAGE="${IMAGE:-docker.io/opencloudeu/opencloud-rolling:latest}"
HTTP_PORT="${HTTP_PORT:-9200}"
OC_DOMAIN="${OC_DOMAIN:-localhost:${HTTP_PORT}}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/opencloud/data}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.local/share/opencloud/config}"

mkdir -p "$DATA_DIR" "$CONFIG_DIR"

podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
podman pull "$IMAGE"

# One-time initialization (creates config files if missing)
if [ ! -f "$CONFIG_DIR/opencloud.yaml" ]; then
  podman run --rm \
    --userns=keep-id \
    -v "$CONFIG_DIR:/etc/opencloud:Z" \
    -v "$DATA_DIR:/var/lib/opencloud:Z" \
    -e OC_URL="https://${OC_DOMAIN}" \
    -e IDM_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
    "$IMAGE" init --insecure true
fi

podman run -d \
  --name "$CONTAINER_NAME" \
  --userns=keep-id \
  --restart=unless-stopped \
  -p "${HTTP_PORT}:9200" \
  -v "$CONFIG_DIR:/etc/opencloud:Z" \
  -v "$DATA_DIR:/var/lib/opencloud:Z" \
  -e OC_URL="https://${OC_DOMAIN}" \
  -e OC_INSECURE=true \
  -e PROXY_HTTP_ADDR=0.0.0.0:9200 \
  -e IDM_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  "$IMAGE"

echo "OpenCloud is starting at https://${OC_DOMAIN} (admin / ${ADMIN_PASSWORD})"
podman logs -f "$CONTAINER_NAME"
