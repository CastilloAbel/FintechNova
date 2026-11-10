#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
dotnet run --no-launch-profile --urls http://127.0.0.1:18084 > /tmp/tarjetas-smoke.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:18084/ > /tmp/tarjetas-response.json; then
    grep -q '"status":"ok"' /tmp/tarjetas-response.json
    grep -q '"servicio":"api-tarjetas"' /tmp/tarjetas-response.json
    echo 'OK: API Tarjetas responde HTTP 200 y JSON esperado'
    exit 0
  fi
  if ! kill -0 "$pid" 2>/dev/null; then cat /tmp/tarjetas-smoke.log; exit 1; fi
  sleep 2
done
cat /tmp/tarjetas-smoke.log
exit 1
