#!/usr/bin/env bash

# start_webtop.sh
#
# This convenience script builds the custom webtop image (if needed) and
# starts the container using the same settings as the docker-compose file.
# It can be run on the Jetson Orin Nano host.  After the container
# starts, the Webtop desktop will be available at http://<device_ip>:3000
# and https://<device_ip>:3001.  An SSH server will listen on
# port 2222 for shell access.  GPU resources will be enabled via the
# default NVIDIA runtime (configure with nvidia‑ctk as shown in the
# documentation【692246732032093†L585-L603】).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[start_webtop] Building the custom webtop image..."
docker build -t webtop-persistent:latest "$SCRIPT_DIR"

echo "[start_webtop] Starting the webtop container..."
docker run -d \
  --name webtop \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/Toronto \
  -e SSH_DEFAULT_PASSWORD=changeme \
  -p 3000:3000 \
  -p 3001:3001 \
  -p 2222:22 \
  -v /opt/webtop/config:/config \
  -v /opt/webtop/home:/home/abc \
  --shm-size=1g \
  --runtime nvidia \
  --gpus all \
  --restart unless-stopped \
  webtop-persistent:latest

echo "[start_webtop] Webtop is starting.  Open your browser at http://<device_ip>:3000"