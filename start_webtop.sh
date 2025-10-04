#!/usr/bin/env bash
# start_webtop.sh
# Build image only if no container named 'webtop' exists yet.
# If running: print status and exit. If stopped: start it. If missing: build (if needed) and run.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE_NAME="your-webtop:latest"
BASE_IMAGE="lscr.io/linuxserver/webtop:ubuntu-xfce"
CONTAINER_NAME="webtop"
L4T_PYTORCH_TAG="${L4T_PYTORCH_TAG:-r36.4.0}"

have_running_container() {
  docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

have_any_container() {
  docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

have_image() {
  docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1
}

detect_base_python_tag() {
  docker run --rm --entrypoint python3 "${BASE_IMAGE}" \
    -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}")'
}

echo "[start_webtop] Checking container state..."

if have_running_container; then
  echo "[start_webtop] '${CONTAINER_NAME}' is already RUNNING. Nothing to do."
  exit 0
fi

if have_any_container; then
  echo "[start_webtop] Found existing '${CONTAINER_NAME}' (stopped). Starting it..."
  docker start "${CONTAINER_NAME}"
  echo "[start_webtop] '${CONTAINER_NAME}' started."
  exit 0
fi

# No container by this name yet → build image only if needed, then run
if have_image; then
  echo "[start_webtop] Using existing image ${IMAGE_NAME} (no build needed)."
else
  echo "[start_webtop] No image found. Building ${IMAGE_NAME}..."

  BASE_PYTHON_ABI=""
  if BASE_PYTHON_ABI=$(detect_base_python_tag 2>/dev/null); then
    echo "[start_webtop] Base image ${BASE_IMAGE} reports ${BASE_PYTHON_ABI}."
  else
    echo "[start_webtop] Warning: unable to detect Python ABI from ${BASE_IMAGE}." >&2
  fi

  echo "[start_webtop] Building with L4T_PYTORCH_TAG=${L4T_PYTORCH_TAG} (override via env)."
  docker build \
    --build-arg "L4T_PYTORCH_TAG=${L4T_PYTORCH_TAG}" \
    -t "${IMAGE_NAME}" \
    "${SCRIPT_DIR}"
fi

echo "[start_webtop] Running new container '${CONTAINER_NAME}'..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/Toronto \
  -e SSH_DEFAULT_PASSWORD=changeme \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -p 3000:3000 \
  -p 3001:3001 \
  -p 2222:22 \
  -p 8888:8888 \
  -v /opt/webtop/config:/config \
  -v /opt/webtop/home:/home/abc \
  --shm-size=1g \
  --runtime nvidia \
  --gpus all \
  --restart unless-stopped \
  "${IMAGE_NAME}"

echo "[start_webtop] Webtop is starting. Open http://<device_ip>:3000  (SSH on port 2222)"
