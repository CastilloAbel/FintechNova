# Runbook: despliegue automático en AWS Academy

## Propósito y alcance

Operar el deploy Terraform que se ejecuta automáticamente en un pipeline `push` de `main`. El flujo integra tests, builds, seguridad, `terraform init/plan/apply`, preparación de EC2, transferencia de imágenes y verificaciones HTTPS.

El pipeline ya no incluye el job legacy `deploy_aws` ni un job `destroy_ec2`. No lanzar este procedimiento si no se acepta que Terraform pueda reemplazar la instancia y su disco raíz.

## Impacto conocido

El state remoto se comparte bajo `fintech-nova-sandbox`. El suffix/key pair cambia por pipeline; un apply posterior puede reemplazar la EC2 administrada por ese state. Su root EBS usa `delete_on_termination`; al reemplazar la instancia se pierden la base MariaDB y demás datos locales. No usar esa DB como almacenamiento persistente. Si se necesitan datos, exportarlos/respaldarlos fuera de EC2 antes de mergear.

No hay un backup automatizado ni un procedimiento de restauración validado por el pipeline. Si se necesita conservar información, no confiar en el volumen de EC2: acordar y probar previamente un mecanismo externo de exportación/restauración o evitar el apply automático mientras haya datos que preservar.

## Prerrequisitos

1. Iniciar AWS Academy Learner Lab y comprobar que la sesión esté activa.
2. En GitLab **Settings → CI/CD → Variables**, renovar las credenciales temporales de `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` y `AWS_DEFAULT_REGION`.
3. Verificar `RUNNER_EGRESS_CIDR` como una IPv4 individual del runner (`/32`); confirmar `TF_STATE_USERNAME`/`TF_STATE_PASSWORD` y las variables de aplicación (`DB_USER`, `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `DASHBOARD_USER`, `DASHBOARD_PASSWORD`, `IPAPI_TOKEN` si aplica).
4. Confirmar que las variables protegidas están disponibles en `main` y que `main` está protegida para aceptar merges mediante MR según la política del repositorio.
5. Revisar que los datos locales de EC2 no sean necesarios. No existe recuperación automática de la base al reemplazar el disco.

Nunca copiar secretos a YAML, al repositorio, a artifacts ni a mensajes del job.

## Procedimiento

1. Crear la feature con el prefijo `feat/` y abrir un MR a `main`.
2. Confirmar que `validar_origen_mr` pasa y que tests, builds y todos los jobs de security finalizan correctamente. Trivy bloquea ante hallazgos `HIGH`/`CRITICAL` corregibles y excluye los no corregibles con `--ignore-unfixed`; revisar sus artifacts y remediar los findings que hagan fallar el job.
3. Aprobar y mergear el MR. El push resultante a `main` ejecuta automáticamente `deploy_terraform` si las etapas previas pasan.
4. En el job, comprobar que el `terraform init`, `plan` y `apply` concluyan. El script compartido `scripts/deploy-ci.sh` prepara SSH, transfiere las ocho imágenes y archivos runtime y ejecuta `deploy.sh`.
5. Confirmar en el log los ocho contenedores, MariaDB healthy y los resultados HTTPS esperados: web y cinco APIs HTTP 200; `/dashboard/` HTTP 401 sin autenticación.
6. Registrar la URL `https://<IP>/`, el commit, pipeline/job IDs, tag de imagen y hora de ejecución. No registrar credenciales ni claves.

## Si el pipeline falla

- **Test/build/security bloqueante:** no se ejecuta el deploy. Resolver el error en una rama, actualizar el MR y esperar un nuevo pipeline exitoso.
- **Trivy:** los hallazgos `HIGH`/`CRITICAL` corregibles bloquean el pipeline y evitan el deploy; los no corregibles se excluyen con `--ignore-unfixed`. Descargar los JSON y seguir [runbook-trivy-vulnerabilities.md](runbook-trivy-vulnerabilities.md) para corregir y volver a ejecutar.
- **Terraform state/auth:** no deshabilitar locking ni usar state local para evadir el error. Verificar vigencia y alcance del token del backend; revisar `terraform init` y lock. No volver a aplicar repetidamente ante un estado incierto.
- **AWS credentials/quotas:** comprobar sesión y región del Learner Lab, revisar los errores concretos del provider y confirmar el estado del state antes de reintentar.
- **SSH/health checks:** revisar `RUNNER_EGRESS_CIDR`, la IP resultante, el Security Group, el setup y logs de Compose. No borrar manualmente recursos que puedan pertenecer al state compartido sin revisar el impacto.
- **Fallo después de `terraform apply`:** Terraform puede haber creado o reemplazado EC2 aunque `scripts/deploy-ci.sh` falle. Inspeccionar state y consola de AWS Academy antes de reintentar. No hay un job automático de destroy.

## Cierre

El job se considera exitoso solo si termina `deploy.sh` y sus health checks. Registrar las evidencias del mismo pipeline/sesión del Lab en `docs/evidencias/`. Los datos históricos de otros despliegues no sustituyen evidencia de la sesión actual.
