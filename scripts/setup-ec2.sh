
#!/usr/bin/env bash
set -euo pipefail

echo "=== Preparando EC2 ==="

# Instalar Docker si todavía no está instalado
if ! command -v docker >/dev/null 2>&1; then
    echo "Instalando Docker..."
    sudo dnf install -y docker
fi

# Iniciar Docker y habilitarlo al arrancar EC2
echo "Iniciando Docker..."
sudo systemctl enable --now docker

# Instalar Docker Compose si todavía no está disponible
if ! sudo docker compose version >/dev/null 2>&1; then
    echo "Instalando Docker Compose..."

    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64) COMPOSE_ARCH="x86_64" ;;
        aarch64) COMPOSE_ARCH="aarch64" ;;
        *) echo "Arquitectura no soportada: $ARCH"; exit 1 ;;
    esac

    COMPOSE_VERSION="v2.40.3"

    sudo mkdir -p /usr/local/lib/docker/cli-plugins

    sudo curl -fSL \
      "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose

    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

echo "=== Verificando instalación ==="
sudo docker --version
sudo docker compose version
sudo docker info >/dev/null

echo "EC2 preparada correctamente."
