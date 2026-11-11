#!/usr/bin/env bash
# Construye y publica las 8 imagenes del TP en un registry.
# Requiere haber ejecutado "docker login" previamente.

set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# Uso: ./scripts/build-ci.sh registry tag image_ref
[[ $# == 3 ]] || fail 'Uso: ./scripts/build-ci.sh registry tag image_ref'

REGISTRY=$1
IMAGE_TAG=$2
IMAGE_REF=$3

# Validaciones basicas
[[ $REGISTRY != *://* && $REGISTRY != */ && $REGISTRY != *[[:space:]]* ]] || fail 'Registry invalido.'
[[ $IMAGE_TAG =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || fail 'Tag invalido.'
[[ $IMAGE_REF != */ && $IMAGE_REF != *[[:space:]]* ]] || fail 'Referencia de imagen invalida.'

command -v docker >/dev/null || fail 'Docker no esta instalado.'
docker info >/dev/null || fail 'Docker no esta iniciado.'

# Imagenes del proyecto
NAMES=(
  "tp1-traefik"
  "tp1-db"
  "tp1-api-clientes"
  "tp1-api-pagos"
  "tp1-api-facturas"
  "tp1-api-tarjetas"
  "tp1-api-transacciones"
  "tp1-web"
)

# Dockerfiles correspondientes
FILES=(
  "traefik/Dockerfile"
  "aplicaciones-contenedores/db/Dockerfile"
  "aplicaciones-contenedores/api-clientes/Dockerfile"
  "aplicaciones-contenedores/api-pagos/Dockerfile"
  "aplicaciones-contenedores/api-facturas/Dockerfile"
  "aplicaciones-contenedores/api-tarjetas/Dockerfile"
  "aplicaciones-contenedores/api-transacciones/Dockerfile"
  "aplicaciones-contenedores/web/Dockerfile"
)

# Contextos de construccion
CONTEXTS=(
  "traefik"
  "aplicaciones-contenedores/db"
  "aplicaciones-contenedores/api-clientes"
  "aplicaciones-contenedores/api-pagos"
  "aplicaciones-contenedores"
  "aplicaciones-contenedores"
  "aplicaciones-contenedores"
  "aplicaciones-contenedores"
)

REFS=()

# Verificar que existan todos los Dockerfiles
for file in "${FILES[@]}"; do
  [[ -f "$file" ]] || fail "Falta $file"
done

# Preparar nombres finales de las imagenes
for name in "${NAMES[@]}"; do
  REFS+=("$IMAGE_REF/$name:$IMAGE_TAG")
done

echo "Se construiran 8 imagenes con:"
echo "Registry:  $REGISTRY"
echo "Base:     $IMAGE_REF"
echo "Tag:       $IMAGE_TAG"
echo

# Primero construir las 8 imagenes.
# Si alguna falla, el script se detiene y no publica ninguna.
for i in "${!REFS[@]}"; do
  echo "Construyendo ${REFS[$i]}"

  docker build \
    --pull \
    --platform linux/amd64 \
    -f "${FILES[$i]}" \
    -t "${REFS[$i]}" \
    "${CONTEXTS[$i]}"
done

echo
echo "Las 8 imagenes se construyeron correctamente."
echo "Comenzando publicacion en el registry..."
echo

# Publicar solo despues de que terminaron correctamente las 8 builds
for ref in "${REFS[@]}"; do
  echo "Publicando $ref"
  docker push "$ref"
  latest_ref="${ref%:*}:latest"
  docker tag "$ref" "$latest_ref"
  docker push "$latest_ref"
done

echo
echo "Proceso terminado."
echo "Las 8 imagenes fueron publicadas bajo:"
echo "$IMAGE_REF con tags $IMAGE_TAG y latest"