# ADR_005: MariaDB compartida con bases lógicas por API

- **Estado:** Aceptada
- **Fecha:** 2026-11-11
- **Decisores:** Grupo 19

## Contexto

La aplicación contiene cinco APIs que persisten información y el alcance del trabajo requiere una base compartida. El despliegue académico utiliza una sola instancia EC2 y busca limitar el consumo de recursos y la complejidad operativa.

## Decisión

Ejecutar una instancia MariaDB como contenedor compartido. Mantener una base lógica para cada API (`db_clientes`, `db_pagos`, `db_facturas`, `db_transacciones` y `db_tarjetas`) y conectar cada servicio por el nombre interno `tp1-db` en la red Docker `proxy`. Persistir los datos del contenedor mediante el volumen nombrado `db_data` montado en `/var/lib/mysql`.

## Alternativas consideradas

- Una instancia de base por API: mayor aislamiento, pero más servicios y consumo de recursos para el alcance de laboratorio.
- Una base compartida para todos los datos: más simple, pero mezcla esquemas y permisos lógicos de las APIs.
- Base administrada externa: mejor ciclo de vida independiente de EC2, pero excede el alcance y las cuotas del Sandbox académico.

## Consecuencias

- Se comparte servidor y capacidad; una caída de MariaDB afecta a las cinco APIs.
- La separación en bases es lógica, no aislamiento físico ni de servidor.
- Compose espera que MariaDB esté `healthy` antes de iniciar las APIs; los health checks de despliegue también contemplan tiempo de inicialización.
- En el modo Compose habitual, recrear contenedores conserva `db_data` si no se elimina el volumen.
- En AWS Terraform, `db_data` vive en el disco raíz de EC2. El volumen EBS tiene `delete_on_termination`; el reemplazo/terminación de la instancia pierde la base de datos. El state remoto de Terraform no contiene esos datos.
- La instancia no debe tratarse como almacenamiento durable. Antes de un apply que pueda reemplazarla, los datos necesarios deben respaldarse fuera de EC2.

## Referencias

- `docker-compose.yml` (`tp1-db`, `db_data`)
- `aplicaciones-contenedores/db/init-scripts/`
- `infra/aws/main.tf` (`root_block_device`)
- `README.md`
- `DEPLOY.md`
