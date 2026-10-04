# DevOps 2026 - Trabajos Prácticos

* [Enunciado Trabajo Práctico - Parte 1](./Enunciado-TP-Parte-1.md)

## Configuración del despliegue

El despliegue con Compose utiliza únicamente `.env` en la raíz. Para una
instalación nueva, copiar `env.example` como `.env` y completar `DB_USER`,
`DB_PASSWORD`, `MYSQL_ROOT_PASSWORD` e `IPAPI_TOKEN`, además de revisar `DOMAIN`.
No sobrescribir un `.env` existente ni compartirlo o versionarlo.

Compose selecciona explícitamente las variables mediante `environment`:
cada API recibe su base, conexión y credenciales; solo Transacciones recibe
`IPAPI_TOKEN`. MariaDB recibe `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE` y las
credenciales comunes, mapeadas a `MYSQL_USER` y `MYSQL_PASSWORD`.
Los `env.example` dentro de los servicios son referencias para ejecución
individual fuera de Compose; no se necesitan para este despliegue.

Se conserva `MYSQL_DATABASE=fintech_nova` como base inicial de MariaDB para un volumen nuevo. Las cinco APIs usan sus propias bases `db_clientes`, `db_pagos`, `db_facturas`, `db_tarjetas` y `db_transacciones`, creadas por los scripts de inicialización. Cambiar `MYSQL_DATABASE` no crea ni renombra bases en un volumen ya inicializado.

Los cinco nombres de base deben coincidir con los scripts SQL de la imagen
publicada. Cambiarlos en `.env` no renombra las bases existentes. Las variables
de inicialización de MariaDB tampoco cambian las credenciales de un volumen
ya inicializado: usar las credenciales actuales.

Desde la raíz, validar sin imprimir secretos y levantar las imágenes publicadas:

```sh
docker compose config --quiet
docker compose up -d
docker compose ps
```

Traefik mantiene HTTPS en 443 y la red `proxy`; las APIs y MariaDB no publican
puertos. Se conservan `restart: always` y los límites de CPU y memoria.
No ejecutar `docker compose down -v` para esta migración: eliminaría los datos.
Evitar compartir la salida de `docker compose config` sin `--quiet`, ya que
incluye los valores resueltos de las variables.
