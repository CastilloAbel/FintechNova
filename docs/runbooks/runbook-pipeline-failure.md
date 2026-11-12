# Runbook: diagnóstico de un pipeline fallido

## Objetivo

Encontrar la primera etapa/job bloqueante, conservar evidencia y corregir la causa sin saltarse controles ni repetir operaciones Terraform a ciegas.

## Procedimiento general

1. Abrir el pipeline por commit y localizar el primer job fallido (no asumir que el último mensaje visible es la causa raíz).
2. Anotar pipeline ID, commit/SHA, rama, job ID y hora. Descargar artifacts/logs relevantes antes de que expire su retención.
3. Clasificar la falla por etapa: tests, build, security o deploy. Revisar la sección específica que sigue.
4. No incorporar secretos en tickets, logs compartidos o commits. Redactar tokens, passwords, `.env`, claves y headers de autorización.
5. Corregir en la rama del MR, ejecutar las validaciones locales disponibles y permitir que un pipeline nuevo compruebe el cambio.

## Test

- API Clientes: revisar instalación de requirements y salida de `unittest`.
- Pagos: revisar `npm ci` y salida de `node --test`.
- Facturas: revisar Maven y resultados JUnit.
- Tarjetas: revisar compilación/inicio y endpoint del smoke test.
- Transacciones: revisar `go test`.
- Terraform: `fmt`, `init -backend=false` y `validate`; esta validación no prueba el backend remoto ni crea recursos.
- Para un MR a `main`, comprobar `validar_origen_mr`: solo permite source branch `feat/*`.

## Build

1. Confirmar qué `build_*` falló y qué Dockerfile/contexto usa.
2. Revisar log de build, versión/tag y disponibilidad del runner/daemon.
3. No desplegar un tag parcial. Verificar que la imagen del commit esté publicada en GitLab Container Registry antes del deploy.

## Security

- Semgrep, Hadolint, Yamllint, Gitleaks y Compose pueden ser bloqueantes según su exit status.
- Trivy bloquea ante hallazgos `HIGH` o `CRITICAL` corregibles; `--ignore-unfixed` excluye los que no tienen parche disponible. Descargar los artifacts y seguir [runbook-trivy-vulnerabilities.md](runbook-trivy-vulnerabilities.md); no continuar al deploy hasta remediar los findings que hicieron fallar el job.
- Un reporte Trivy incompleto o job sin artifacts requiere investigar acceso al Registry, conectividad y error del scanner; no considerarlo escaneo limpio.

## Deploy / Terraform

1. Confirmar que el job se ejecutó en un pipeline `push` de `main` y que todos los jobs previos necesarios terminaron correctamente.
2. Verificar que AWS Academy esté activo y que las variables protegidas AWS/State tengan alcance a `main` y sigan vigentes.
3. Revisar en orden `terraform init`, `validate`, `plan`, `apply`, salida de IP, SSH, transferencia de imágenes y health checks.
4. Si falla antes de `apply`, normalmente no se llegó a cambiar infraestructura; aun así, revisar los logs exactos.
5. Si falla durante o después de `apply`, no repetir inmediatamente. El provider puede haber creado/reemplazado recursos antes del error. Revisar el state remoto `fintech-nova-sandbox`, la consola del Lab y el estado EC2/SG/key pair.
6. Si falla SSH, comprobar `RUNNER_EGRESS_CIDR`, la regla 22, la clave pública registrada y la IP de EC2.
7. Si falla deploy/health check, comprobar que las ocho imágenes fueron transferidas y revisar `docker compose ps/logs` por SSH si la instancia sigue accesible.
8. Recordar que apply sucesivo puede reemplazar EC2 y borrar root EBS/DB local. El pipeline no tiene destroy; AWS Academy puede expirar/resetear recursos.
9. No eliminar manualmente state, EC2, Security Groups o key pairs sin analizar qué administra Terraform. No desactivar locking ni cambiar el state como workaround.

## Criterio de cierre

Cerrar la incidencia cuando exista un pipeline nuevo con el commit corregido y estado claro de la infraestructura. Registrar la causa y solución en `ERRORES.md`; si produjo impacto o reveló una falla de proceso relevante, redactar un postmortem en `docs/postmortems/`.
