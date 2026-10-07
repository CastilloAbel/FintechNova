#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ $# -eq 1 ]] || fail 'Uso: bash prepare-deploy.sh <usuario-dashboard>'
username=$1
[[ $username =~ ^[A-Za-z0-9_.-]+$ ]] || \
  fail 'El usuario solo puede contener letras, números, punto, guion y guion bajo.'

[[ -d certs ]] || fail 'No existe la carpeta certs/.'
[[ -d secrets ]] || fail 'No existe la carpeta secrets/.'
command -v openssl >/dev/null || fail 'Se requiere OpenSSL en la PC.'
command -v docker >/dev/null || fail 'Se requiere Docker en la PC.'
docker info >/dev/null 2>&1 || fail 'Docker no está iniciado en la PC.'

if [[ -f secrets/dashboard_users ]] && \
  awk -F: -v user="$username" '$1 == user { found=1 } END { exit !found }' secrets/dashboard_users; then
  fail "El usuario '$username' ya existe en secrets/dashboard_users. Elige otro usuario para agregarlo."
fi

IFS= read -r -s -p 'Contraseña del dashboard: ' password
printf '\n' >&2
IFS= read -r -s -p 'Repite la contraseña: ' password_confirmation
printf '\n' >&2
[[ -n $password ]] || fail 'La contraseña no puede estar vacía.'
[[ $password == "$password_confirmation" ]] || fail 'Las contraseñas no coinciden.'
unset password_confirmation

# htpasswd lee la contraseña por stdin: no se pasa como argumento ni se imprime.
hash_line=$(printf '%s\n' "$password" | docker run --rm -i httpd:2.4 htpasswd -ni "$username") || \
  fail 'No se pudo generar el hash de la contraseña con Docker.'
unset password
[[ $hash_line == "$username":* ]] || fail 'htpasswd devolvió una salida inesperada.'

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$work_dir/local.key" \
  -out "$work_dir/local.crt" \
  -subj '/CN=*.19.grupo.devops.frc.utn.edu.ar' \
  >/dev/null 2>&1 || fail 'No se pudo generar el certificado TLS.'

# El certificado se reemplaza en cada ejecución; la clave privada queda solo para su propietario.
install -m 600 "$work_dir/local.key" certs/local.key
install -m 644 "$work_dir/local.crt" certs/local.crt
# A file may end without LF; add a separator before appending another htpasswd record.
if [[ -s secrets/dashboard_users ]] && \
  [[ $(tail -c 1 secrets/dashboard_users | wc -l) -eq 0 ]]; then
  printf '\n' >> secrets/dashboard_users
fi
printf '%s\n' "$hash_line" >> secrets/dashboard_users
chmod 600 secrets/dashboard_users

printf 'Certificado generado en certs/local.crt y certs/local.key.\n'
printf "Usuario '$username' agregado a secrets/dashboard_users.\n"
printf 'Ya puedes copiar los archivos a EC2 y ejecutar deploy.sh.\n'
