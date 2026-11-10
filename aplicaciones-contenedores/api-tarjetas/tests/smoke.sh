#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

# Primero compilar y esperar a que termine
dotnet build --configuration Release

# Después iniciar la API sin volver a compilar
dotnet run --no-build --configuration Release \
  --no-launch-profile --urls http://0.0.0.0:8080 \
  > /tmp/tarjetas-smoke.log 2>&1 &

pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

# Esperar a que la API responda
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8080/ > /tmp/tarjetas-response.json 2>/dev/null; then
    grep -q '"status":"ok"' /tmp/tarjetas-response.json
    grep -q '"servicio":"api-tarjetas"' /tmp/tarjetas-response.json
    echo "OK: API Tarjetas responde correctamente"
    exit 0
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    cat /tmp/tarjetas-smoke.log
    exit 1
  fi

  sleep 2
done

cat /tmp/tarjetas-smoke.log
exit 1
