# Análisis de seguridad

Este documento resume los resultados de los artifacts generados por el pipeline de la rama `ci-seguridad`. Los reportes fuente se conservaron en `security/`, organizados por herramienta.

## Alcance y política

El análisis cubre el código fuente, los ocho Dockerfiles, los archivos YAML y las ocho imágenes publicadas en el Container Registry de GitLab.

La política definida para esta entrega es:

- Semgrep bloquea ante hallazgos de severidad `ERROR`.
- Trivy bloquea ante vulnerabilidades `HIGH` o `CRITICAL`.
- Hadolint y Yamllint bloquean ante errores detectados.
- Gitleaks bloquea si encuentra secretos en el repositorio.
- Una excepción solo puede aceptarse cuando no existe una corrección disponible y queda justificada en este documento y en `SEGURIDAD.md`.

## SAST: `analizar_codigo_semgrep`

El artifact `security/semgrep/semgrep-report.json` fue generado por Semgrep 1.181.1 y analizó 95 archivos. Encontró cuatro hallazgos bloqueantes, todos relacionados con la ejecución como `root` en imágenes Docker:

| Archivo | Línea | Regla | Hallazgo | Tratamiento |
|---|---:|---|---|---|
| `aplicaciones-contenedores/api-clientes/Dockerfile` | 13 | `dockerfile.security.missing-user.missing-user` | No se declaraba un usuario no root para el proceso Python. | Corregido con usuario `appuser` y grupo `appgroup`. Requiere reconstrucción y nuevo escaneo. |
| `aplicaciones-contenedores/api-pagos/Dockerfile` | 13 | `dockerfile.security.missing-user.missing-user` | No se declaraba un usuario no root para el proceso Node.js. | Corregido usando el usuario `node`. Requiere reconstrucción y nuevo escaneo. |
| `aplicaciones-contenedores/api-transacciones/Dockerfile` | 20 | `dockerfile.security.missing-user-entrypoint.missing-user-entrypoint` | El binario Go se ejecutaba como `root`. | Corregido con usuario `appuser` y permisos de propietario. Requiere reconstrucción y nuevo escaneo. |
| `traefik/Dockerfile` | 6 | `dockerfile.security.missing-user-entrypoint.missing-user-entrypoint` | Traefik se ejecutaba como `root`. | Corregido declarando el usuario no root `65532`. Requiere reconstrucción y nuevo escaneo. |

La corrección reduce privilegios de los procesos en runtime. Las etapas de compilación de Facturas y Tarjetas ya utilizaban usuarios no root en sus imágenes finales.

## Análisis de imágenes: `analizar_imagenes_trivy`

Los ocho reportes fueron generados contra el tag `3114522c`. El conteo corresponde a vulnerabilidades `HIGH` y `CRITICAL` detectadas por el pipeline:

| Imagen | HIGH | CRITICAL | Total | Componentes observados |
|---|---:|---:|---:|---|
| `tp1-traefik` | 0 | 0 | 0 | Sin vulnerabilidades HIGH/CRITICAL en el reporte. |
| `tp1-db` | 44 | 1 | 45 | Paquetes del sistema Red Hat, principalmente utilidades y librerías base. |
| `tp1-api-clientes` | 26 | 3 | 29 | Alpine, `libcrypto3`/`libssl3` y dependencias Python. |
| `tp1-api-pagos` | 26 | 1 | 27 | Alpine, OpenSSL y dependencias Node.js. |
| `tp1-api-facturas` | 30 | 8 | 38 | Ubuntu y dependencias Java, especialmente Jackson. |
| `tp1-api-tarjetas` | 32 | 1 | 33 | Paquetes del sistema Debian y runtime .NET. |
| `tp1-api-transacciones` | 25 | 1 | 26 | Alpine y `stdlib` de Go, además de librerías del sistema. |
| `tp1-web` | 52 | 3 | 55 | Alpine, OpenSSL y dependencias Node.js. |

El resultado inicial contiene vulnerabilidades corregibles y vulnerabilidades cuya corrección depende de la publicación de una actualización de la distribución o del proveedor de la dependencia. No se debe aceptar el riesgo únicamente por el volumen de hallazgos: primero se deben actualizar las imágenes base y dependencias con versión corregida, reconstruir y volver a escanear.

Trivy descargó su base de vulnerabilidades y la Java DB durante el primer análisis. Esto explica parte de la duración del job. El pipeline debe conservar cache de Trivy o reutilizar la base del runner cuando la infraestructura lo permita.

El job falla de forma intencional mientras existan estos hallazgos, porque la política definida bloquea `HIGH` y `CRITICAL`. El siguiente trabajo no es modificar el código del escáner, sino actualizar las imágenes base y dependencias con `FixedVersion`, reconstruirlas y volver a medir. Los hallazgos sin parche disponible deberán quedar identificados y justificados antes de aceptar una excepción.

## Dockerfiles: `analizar_dockerfiles`

Hadolint analizó los ocho Dockerfiles. El artifact inicial detectó:

- `DL3021` en `aplicaciones-contenedores/web/Dockerfile`: corregido cambiando `COPY web . .` por `COPY web/ .`.
- `DL3018` informativo en la instalación de `ca-certificates` de Transacciones: queda como mejora pendiente para fijar la versión del paquete de Alpine.
- `DL3066` informativo en usuarios nombrados: no bloquea la ejecución, pero puede reemplazarse por UID/GID numéricos si el runtime lo requiere.

Hadolint no utiliza `--no-fail`, por lo que un error real del Dockerfile bloquea el job.

## YAML: `analizar_archivos_yaml`

Yamllint revisa `.gitlab-ci.yml`, `docker-compose.yml` y la configuración de Traefik. El job usa entrypoint vacío porque la imagen de Yamllint tiene una entrada predeterminada que impediría que GitLab ejecute el shell del job. El reporte se publica como `yamllint-report.txt`.

## Secretos: `detectar_secretos`

Gitleaks analiza el árbol del repositorio con salida redactada y publica `gitleaks-report.json`. El artifact `security/gitleaks/gitleaks-report.json` no contiene hallazgos. Los archivos `.env`, claves privadas, certificados y secretos de Traefik permanecen excluidos por `.gitignore`; cualquier credencial que haya sido expuesta debe revocarse, no solo borrarse del archivo.

## Próximas acciones

1. Reconstruir las cuatro imágenes modificadas y volver a ejecutar `analizar_codigo_semgrep`.
2. Actualizar imágenes base y dependencias indicadas por `FixedVersion` en los reportes Trivy.
3. Reconstruir las ocho imágenes y repetir el escaneo con el mismo tag de commit.
4. Registrar aquí los hallazgos que no tengan parche disponible, junto con su justificación y medida compensatoria.
5. Adjuntar la evidencia final de los reportes generados por el pipeline.

Los reportes JSON completos no se reproducen aquí porque contienen información extensa de paquetes y referencias. La fuente auditable permanece en `security/` y en los artifacts de `analizar_codigo_semgrep`, `analizar_imagenes_trivy` y `detectar_secretos`.
