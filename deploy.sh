#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for file in .env docker-compose.yml certs/local.crt certs/local.key secrets/dashboard_users; do
  [[ -s $file ]] || fail "Falta el archivo requerido: $file"
done

# Restringe los archivos que contienen credenciales o claves privadas.
chmod 600 .env certs/local.key secrets/dashboard_users

command -v dnf >/dev/null || fail 'Este script requiere Amazon Linux 2023.'
sudo dnf install -y docker
command -v curl >/dev/null || fail 'No se encontró curl. Amazon Linux 2023 normalmente incluye curl-minimal.'
sudo systemctl enable --now docker

case "$(uname -m)" in
  x86_64) compose_arch=x86_64 ;;
  aarch64) compose_arch=aarch64 ;;
  *) fail "Arquitectura no soportada: $(uname -m)" ;;
esac

compose_tmp=$(mktemp -d)
trap 'rm -rf -- "$compose_tmp"' EXIT
compose_asset="docker-compose-linux-${compose_arch}"
compose_url="https://github.com/docker/compose/releases/latest/download"
curl -fsSL --retry 3 "$compose_url/$compose_asset" -o "$compose_tmp/$compose_asset"
curl -fsSL --retry 3 "$compose_url/$compose_asset.sha256" -o "$compose_tmp/checksum"
(cd "$compose_tmp" && sha256sum -c checksum)
sudo install -D -m 755 "$compose_tmp/$compose_asset" /usr/local/lib/docker/cli-plugins/docker-compose
sudo docker compose version

# Se usa sudo para Docker; instalar el plugin en /usr/local permite que root lo encuentre.
dc() {
  sudo docker compose -f docker-compose.yml "$@"
}

dc config --quiet
images=$(dc config --images)
[[ $(grep -c . <<< "$images") -eq 8 ]] || fail 'Se esperaban 8 imágenes configuradas.'
grep -qE '^/|:$' <<< "$images" && fail 'Completa DOCKER_USER e IMAGE_TAG en .env.'

# Las imágenes ya fueron transferidas desde GitLab mediante SSH.
# EC2 no necesita acceder al Container Registry.

dc up -d --no-build --pull never
dc ps

running=$(dc ps --status running --quiet | awk 'END { print NR }')
[[ $running -eq 8 ]] || {
  dc ps
  fail "Hay $running de 8 contenedores en ejecución. Desde esta carpeta revisa los logs con: sudo docker compose -f docker-compose.yml logs"
}

check_http() {
  local path=$1
  local expected=$2
  local status=000
  local attempt

  for attempt in {1..40}; do
    status=$(curl -k -sS --connect-timeout 5 --max-time 15 \
      -o /dev/null -w '%{http_code}' "https://127.0.0.1$path") || status=000
    if [[ $status == "$expected" ]]; then
      echo "OK HTTPS $path (HTTP $status)"
      return 0
    fi
    sleep 3
  done

  fail "HTTPS $path devolvió HTTP $status; se esperaba $expected. Revisa los logs de Docker."
}

check_http / 200
for api in clientes pagos facturas transacciones tarjetas; do
  check_http "/api/$api" 200
done
check_http /dashboard/ 401

echo 'Despliegue y verificaciones completados.'
