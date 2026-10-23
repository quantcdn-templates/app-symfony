#!/bin/bash
# Fail loudly if no real APP_SECRET is set. Never fall back to a weak or shared secret.
# This file is sourced by /quant/entrypoints.sh, so "exit" stops the container.

if [ -z "${APP_SECRET:-}" ] || [ "${APP_SECRET}" = "change_me_in_production" ]; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: APP_SECRET is not set. Set it as a secret (Quant Cloud generates one) or in docker-compose.override.yml for local development." >&2
  exit 1
fi
