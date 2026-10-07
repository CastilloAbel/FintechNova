#!/usr/bin/env bash
# Despliegue automatizado del TP en EC2.
#
# Uso:
#   bash deploy.sh check  camilagea 1.0.0
#   bash deploy.sh deploy camilagea 1.0.0
#   bash deploy.sh verify camilagea 1.0.0

set -Eeuo pipefail
umask 077

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# ============================================================
# PARAMETROS
# ============================================================

MODE=${1:-}

case "$MODE" in
  check|deploy|verify) ;;
  *)
    fail 'Uso: bash deploy.sh [check|deploy|verify] namespace tag'
    ;;
esac

[[ $# == 3 ]] || \
  fail 'Uso: bash deploy.sh [check|deploy|verify] namespace tag'

DOCKER_USER=$2
IMAGE_TAG=$3

[[ $DOCKER_USER =~ ^[a-z0-9][a-z0-9_-]*$ ]] || \
  fail 'Namespace Docker Hub invalido.'

[[ $IMAGE_TAG =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || \
  fail 'Tag invalido.'

# Variables utilizadas por docker-compose.yml
export DOCKER_USER IMAGE_TAG

# ============================================================
# REQUISITOS LOCALES
# ============================================================

command -v docker >/dev/null || \
  fail 'Falta Docker en la maquina local.'

command -v curl >/dev/null || \
  fail 'Falta curl en la maquina local.'

if command -v python3 >/dev/null &&
   python3 -c 'import sys' >/dev/null 2>&1; then

  PYTHON=python3

elif command -v python >/dev/null &&
     python -c 'import sys; assert sys.version_info.major == 3' >/dev/null 2>&1; then

  PYTHON=python

else
  fail 'Se requiere Python 3 local.'
fi

TMP=$(mktemp -d)

trap 'rm -rf -- "$TMP"' EXIT
trap 'echo "Fallo el paso de la linea $LINENO. No se eliminaron volumenes." >&2' ERR

# ============================================================
# CONFIGURACION LOCAL
# ============================================================

[[ -s .env ]] || \
  fail 'Falta .env en la raiz del proyecto.'

# ============================================================
# VALIDAR DOCKER COMPOSE
# ============================================================

docker compose \
  --env-file .env \
  -f docker-compose.yml \
  config --quiet

docker compose \
  --env-file .env \
  -f docker-compose.yml \
  config --format json > "$TMP/config.json"

# ============================================================
# VALIDACIONES DEL PROYECTO
# ============================================================

"$PYTHON" - "$TMP/config.json" "$TMP/host" "$MODE" <<'PY'
import json
import re
import sys

c = json.load(open(sys.argv[1]))
s = c['services']
mode = sys.argv[3]

names = [
    'traefik',
    'tp1-db',
    'tp1-api-clientes',
    'tp1-api-pagos',
    'tp1-api-facturas',
    'tp1-api-transacciones',
    'tp1-api-tarjetas',
    'tp1-web'
]

if set(s) != set(names):
    sys.exit('El script espera los ocho servicios actuales del TP.')

# Validar MariaDB
e = s['tp1-db']['environment']

for key in [
    'MYSQL_ROOT_PASSWORD',
    'MYSQL_USER',
    'MYSQL_PASSWORD',
    'MYSQL_DATABASE'
]:
    if not e.get(key):
        sys.exit(
            'Falta configuracion privada de MariaDB: ' + key
        )

# Validar conexion de las APIs
for api in [
    'clientes',
    'pagos',
    'facturas',
    'transacciones',
    'tarjetas'
]:
    a = s['tp1-api-' + api]['environment']

    if (
        a.get('DB_HOST') != 'tp1-db'
        or str(a.get('DB_PORT')) != '3306'
        or a.get('DB_NAME') != 'db_' + api
    ):
        sys.exit(
            'Revisar configuracion de conexion de ' + api
        )

    if (
        a.get('DB_USER') != e['MYSQL_USER']
        or a.get('DB_PASSWORD') != e['MYSQL_PASSWORD']
    ):
        sys.exit(
            'Credenciales inconsistentes en ' + api
        )

# DOMAIN solo es obligatorio para deploy/verify.
h = s['traefik']['environment'].get('DOMAIN', '')

if mode != 'check':
    if (
        not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', h)
        or h.endswith('localhost')
    ):
        sys.exit(
            'Para AWS completar DOMAIN con IP/DNS publico en .env.'
        )

if h:
    open(
        sys.argv[2],
        'w',
        newline='\n'
    ).write(h + '\n')
PY

# ============================================================
# MODO CHECK
# Solo valida configuracion local.
# No necesita EC2.
# ============================================================

if [[ $MODE == check ]]; then
  echo
  echo 'Comprobacion local correcta.'
  echo "Docker Hub: $DOCKER_USER"
  echo "Tag: $IMAGE_TAG"
  echo 'No se contacto AWS.'
  echo 'No se construyeron ni publicaron imagenes.'
  exit 0
fi

# ============================================================
# CONFIGURACION NECESARIA PARA AWS
# Solo se valida en deploy / verify.
# ============================================================

[[ ${EC2_HOST:-} =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || \
  fail 'Definir EC2_HOST con la IP o DNS actual de la EC2.'

SSH_USER=${SSH_USER:-ec2-user}

[[ $SSH_USER =~ ^[a-z_][a-z0-9_-]*$ ]] || \
  fail 'SSH_USER invalido.'

REMOTE_DIR=${REMOTE_DIR:-/home/$SSH_USER/tp-1}

[[ $REMOTE_DIR =~ ^/home/$SSH_USER/[A-Za-z0-9_-]+$ ]] || \
  fail 'REMOTE_DIR debe ser /home/USUARIO/NOMBRE, sin espacios.'

PROJECT_NAME=${PROJECT_NAME:-tp-1}

[[ $PROJECT_NAME =~ ^[a-z0-9][a-z0-9_-]*$ ]] || \
  fail 'PROJECT_NAME invalido.'

TARGET="$SSH_USER@$EC2_HOST"

HOST=$(cat "$TMP/host")

# ============================================================
# VERIFY
#
# verify solamente comprueba el sistema que ya esta desplegado.
# No necesita SSH ni archivos locales de certificados.
# ============================================================

if [[ $MODE == verify ]]; then
  :
else
  # ==========================================================
  # DEPLOY necesita SSH, SCP, clave y archivos privados.
  # ==========================================================

  command -v ssh >/dev/null || \
    fail 'Falta ssh en la maquina local.'

  command -v scp >/dev/null || \
    fail 'Falta scp en la maquina local.'

  [[ -f ${SSH_KEY:-} ]] || \
    fail 'Definir SSH_KEY con la ruta de la clave SSH.'

  for file in \
    certs/local.crt \
    certs/local.key \
    secrets/dashboard_users
  do
    [[ -s $file ]] || \
      fail "Falta $file."
  done
fi

# ============================================================
# FUNCIONES SSH / SCP
# Solo se utilizaran durante deploy.
# ============================================================

remote() {
  local key=$SSH_KEY

  if command -v cygpath >/dev/null &&
     [[ $(command -v ssh) == */[Oo]penSSH/* ]]; then
    key=$(cygpath -m "$key")
  fi

  MSYS_NO_PATHCONV=1 ssh \
    -i "$key" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    "$TARGET" "$@"
}

upload() {
  local key=$SSH_KEY
  local source=$1

  if command -v cygpath >/dev/null &&
     [[ $(command -v scp) == */[Oo]penSSH/* ]]; then
    key=$(cygpath -m "$key")
    source=$(cygpath -m "$source")
  fi

  MSYS_NO_PATHCONV=1 scp \
    -i "$key" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    "$source" "$TARGET:$2"
}

# ============================================================
# MODO DEPLOY
# ============================================================

if [[ $MODE == deploy ]]; then

  # Preparar Amazon Linux 2023
  remote bash -s <<'REMOTE'
set -Eeuo pipefail

. /etc/os-release

[[ $ID == amzn && $VERSION_ID == 2023 && $(uname -m) == x86_64 ]] || {
  echo 'Se requiere EC2 Amazon Linux 2023 x86_64.' >&2
  exit 1
}

sudo dnf install -y docker
sudo systemctl enable --now docker

version=v2.39.4
asset=docker-compose-linux-x86_64

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

curl -fsSL --retry 3 \
  "https://github.com/docker/compose/releases/download/$version/$asset" \
  -o "$tmp/$asset"

curl -fsSL --retry 3 \
  "https://github.com/docker/compose/releases/download/$version/$asset.sha256" \
  -o "$tmp/checksum"

(
  cd "$tmp"
  sha256sum -c checksum
)

sudo install -d -m 755 \
  /usr/local/lib/docker/cli-plugins

sudo install -m 755 \
  "$tmp/$asset" \
  /usr/local/lib/docker/cli-plugins/docker-compose

sudo docker compose version
REMOTE

  # Crear estructura remota
  remote \
    "umask 077; mkdir -p '$REMOTE_DIR/certs' '$REMOTE_DIR/secrets'"

  # Copiar archivos
  upload \
    docker-compose.yml \
    "$REMOTE_DIR/docker-compose.yml"

  upload \
    .env \
    "$REMOTE_DIR/.env"

  upload \
    certs/local.crt \
    "$REMOTE_DIR/certs/local.crt"

  upload \
    certs/local.key \
    "$REMOTE_DIR/certs/local.key"

  upload \
    secrets/dashboard_users \
    "$REMOTE_DIR/secrets/dashboard_users"

  # ==========================================================
  # DESPLEGAR
  # ==========================================================

  remote bash -s -- \
    "$REMOTE_DIR" \
    "$PROJECT_NAME" \
    "$DOCKER_USER" \
    "$IMAGE_TAG" <<'REMOTE'

set -Eeuo pipefail

dir=$1
project=$2
docker_user=$3
image_tag=$4

cd "$dir"

export DOCKER_USER="$docker_user"
export IMAGE_TAG="$image_tag"

sudo --preserve-env=DOCKER_USER,IMAGE_TAG \
  docker compose \
  --project-name "$project" \
  --env-file .env \
  -f docker-compose.yml \
  config --quiet

sudo --preserve-env=DOCKER_USER,IMAGE_TAG \
  docker compose \
  --project-name "$project" \
  --env-file .env \
  -f docker-compose.yml \
  pull

sudo --preserve-env=DOCKER_USER,IMAGE_TAG \
  docker compose \
  --project-name "$project" \
  --env-file .env \
  -f docker-compose.yml \
  up -d

sudo --preserve-env=DOCKER_USER,IMAGE_TAG \
  docker compose \
  --project-name "$project" \
  --env-file .env \
  -f docker-compose.yml \
  ps

REMOTE

fi

# ============================================================
# VERIFICACION HTTPS
# Se ejecuta despues de deploy o directamente con verify.
# ============================================================

check() {
  local path=$1
  local type=$2
  local status
  local attempt

  for attempt in {1..40}; do

    status=$(
      curl -k -sS \
        --connect-timeout 5 \
        --max-time 15 \
        -o "$TMP/body" \
        -w '%{http_code}' \
        "https://$HOST$path"
    ) || status=000

    if [[ $status == 200 ]] &&
       "$PYTHON" - "$TMP/body" "$type" <<'PY'
import json
import sys

raw = open(
    sys.argv[1],
    encoding='utf-8'
).read()

if sys.argv[2] == 'json':
    try:
        obj = json.loads(raw)
    except ValueError:
        sys.exit(1)

    sys.exit(
        0 if isinstance(obj, list) else 1
    )

sys.exit(
    0 if '<html' in raw.lower() else 1
)
PY
    then
      echo "OK HTTPS $path"
      return
    fi

    sleep 3
  done

  fail \
    "Fallo HTTPS $path (ultimo HTTP $status). Revisar logs en EC2."
}

# Web
check / html

# APIs
for api in \
  clientes \
  pagos \
  facturas \
  transacciones \
  tarjetas
do
  check "/api/$api" json
done

# Dashboard debe solicitar autenticacion
status=$(
  curl -k -sS \
    --connect-timeout 5 \
    --max-time 15 \
    -o /dev/null \
    -w '%{http_code}' \
    "https://$HOST/dashboard/"
)

[[ $status == 401 ]] || \
  fail "Dashboard sin credenciales: HTTP $status, se esperaba 401."

echo
echo 'Web y cinco APIs comprobadas correctamente.'
echo 'El dashboard exige autenticacion.'