#!/usr/bin/env bash

# stop_webtop.sh
#
# This script stops and removes the running webtop container.  It makes no
# changes to the persistent volumes, so your configuration and user data
# remain intact.  To rebuild the container from scratch, simply run
# start_webtop.sh again.

set -e

if docker ps --format '{{.Names}}' | grep -q '^webtop$'; then
  echo "[stop_webtop] Stopping webtop container..."
  docker stop webtop
  echo "[stop_webtop] Removing webtop container..."
  docker rm webtop
else
  echo "[stop_webtop] No running webtop container found."
fi