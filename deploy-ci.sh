#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

required_vars=(
  DEPLOY_SSH_KEY AWS_EC2_HOST AWS_EC2_USER
  CI_REGISTRY CI_REGISTRY_USER CI_REGISTRY_PASSWORD CI_PROJECT_PATH IMAGE_TAG
  DB_USER DB_PASSWORD MYSQL_ROOT_PASSWORD DASHBOARD_USER DASHBOARD_PASSWORD
)
for name in "${required_vars[@]}"; do
  [[ -n ${!name:-} ]] || fail "Falta la variable requerida: $name"
done
[[ -s $DEPLOY_SSH_KEY ]] || fail 'La clave SSH no existe o está vacía.'

python3 - "$AWS_EC2_HOST" "$DASHBOARD_USER" <<'PY'
import ipaddress
import re
import sys

try:
    address = ipaddress.ip_address(sys.argv[1])
except ValueError:
    raise SystemExit("AWS_EC2_HOST debe ser una dirección IPv4 pública")
if address.version != 4:
    raise SystemExit("AWS_EC2_HOST debe ser una dirección IPv4 pública")
if not re.fullmatch(r"[A-Za-z0-9_.-]+", sys.argv[2]):
    raise SystemExit("DASHBOARD_USER solo puede contener letras, números, punto, guion y guion bajo")
PY

chmod 600 "$DEPLOY_SSH_KEY"
DEPLOY_TMP_DIR=$(mktemp -d)
export DOCKER_CONFIG="$DEPLOY_TMP_DIR/docker"
mkdir -p "$DOCKER_CONFIG"
cleanup() {
  rm -rf -- "$DEPLOY_TMP_DIR"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

SSH_CONFIG="$DEPLOY_TMP_DIR/ssh_config"
KNOWN_HOSTS="$DEPLOY_TMP_DIR/known_hosts"
scan_attempt=0
while (( scan_attempt < 12 )); do
  if ssh-keyscan -T 5 -H "$AWS_EC2_HOST" > "$KNOWN_HOSTS" 2>/dev/null && [[ -s $KNOWN_HOSTS ]]; then
    break
  fi
  scan_attempt=$((scan_attempt + 1))
  sleep 5
done
[[ -s $KNOWN_HOSTS ]] || fail "No se pudo obtener la host key SSH de $AWS_EC2_HOST"

cat > "$SSH_CONFIG" <<EOF
Host fintech-nova
  HostName $AWS_EC2_HOST
  User $AWS_EC2_USER
  IdentityFile $DEPLOY_SSH_KEY
  UserKnownHostsFile $KNOWN_HOSTS
  StrictHostKeyChecking yes
  BatchMode yes
  ConnectTimeout 10
EOF
chmod 600 "$SSH_CONFIG" "$KNOWN_HOSTS"

ssh_deploy() {
  ssh -F "$SSH_CONFIG" fintech-nova "$@"
}
scp_deploy() {
  scp -F "$SSH_CONFIG" "$@"
}

echo "Preparando Docker y Docker Compose en EC2..."
scp_deploy setup-ec2.sh fintech-nova:~/setup-ec2.sh
ssh_deploy "bash ~/setup-ec2.sh"

printf '%s' "$CI_REGISTRY_PASSWORD" |
  docker login "$CI_REGISTRY" --username "$CI_REGISTRY_USER" --password-stdin

image_names=(
  tp1-traefik
  tp1-db
  tp1-api-clientes
  tp1-api-pagos
  tp1-api-facturas
  tp1-api-tarjetas
  tp1-api-transacciones
  tp1-web
)
for image_name in "${image_names[@]}"; do
  image_ref="$CI_REGISTRY/$CI_PROJECT_PATH/$image_name:$IMAGE_TAG"
  echo "Descargando y transfiriendo $image_name..."
  docker pull "$image_ref"
  docker save "$image_ref" | ssh_deploy "sudo docker load"
done

ssh_deploy "sudo docker image ls"
ssh_deploy "mkdir -p ~/fintech-nova/certs ~/fintech-nova/secrets"
scp_deploy docker-compose.yml deploy.sh fintech-nova:~/fintech-nova/

export DOCKER_USER="$CI_REGISTRY/$CI_PROJECT_PATH"
export DOMAIN="$AWS_EC2_HOST"
export DB_HOST=tp1-db
export DB_PORT=3306
export MYSQL_DATABASE=fintech_nova
export DB_NAME_CLIENTES=db_clientes
export DB_NAME_PAGOS=db_pagos
export DB_NAME_FACTURAS=db_facturas
export DB_NAME_TARJETAS=db_tarjetas
export DB_NAME_TRANSACCIONES=db_transacciones

python3 - <<'PY' > "$DEPLOY_TMP_DIR/deployment.env"
import os

keys = [
    "DOCKER_USER", "IMAGE_TAG", "DOMAIN", "DB_HOST", "DB_PORT", "DB_USER",
    "DB_PASSWORD", "MYSQL_ROOT_PASSWORD", "MYSQL_DATABASE", "DB_NAME_CLIENTES",
    "DB_NAME_PAGOS", "DB_NAME_FACTURAS", "DB_NAME_TARJETAS",
    "DB_NAME_TRANSACCIONES", "IPAPI_TOKEN",
]
for key in keys:
    value = os.environ.get(key, "")
    if "\n" in value or "\r" in value:
        raise ValueError(f"Valor inválido para {key}")
    print(f"{key}={value}")
PY
chmod 600 "$DEPLOY_TMP_DIR/deployment.env"
scp_deploy "$DEPLOY_TMP_DIR/deployment.env" fintech-nova:~/fintech-nova/.env

printf '%s\n' "$DASHBOARD_PASSWORD" |
  htpasswd -B -i -c "$DEPLOY_TMP_DIR/dashboard_users" "$DASHBOARD_USER"
scp_deploy "$DEPLOY_TMP_DIR/dashboard_users" fintech-nova:~/dashboard_users.tmp
ssh_deploy "sudo install -o 65532 -g 0 -m 640 ~/dashboard_users.tmp ~/fintech-nova/secrets/dashboard_users && rm -f ~/dashboard_users.tmp"

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$DEPLOY_TMP_DIR/local.key" \
  -out "$DEPLOY_TMP_DIR/local.crt" \
  -days 365 \
  -subj "/CN=$AWS_EC2_HOST" \
  -addext "subjectAltName=IP:$AWS_EC2_HOST"
scp_deploy "$DEPLOY_TMP_DIR/local.crt" "$DEPLOY_TMP_DIR/local.key" fintech-nova:~/fintech-nova/certs/

ssh_deploy "cd ~/fintech-nova && chmod 600 .env certs/local.key && chmod +x deploy.sh && ./deploy.sh"
echo "Despliegue verificado correctamente."
echo "Aplicacion: https://$AWS_EC2_HOST/"
echo "Dashboard: https://$AWS_EC2_HOST/dashboard/"
