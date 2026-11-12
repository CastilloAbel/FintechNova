# ADR_008: Gate bloqueante de vulnerabilidades Trivy

- **Estado:** Aceptada
- **Fecha:** 2026-11-12
- **Decisores:** Grupo 19
- **Reemplaza:** [ADR_007](ADR_007-ci-testing-and-security-gates.md), únicamente en la política de tolerancia al fallo y umbral de Trivy.

## Contexto

La política anterior permitía que el pipeline continuara aunque Trivy detectara vulnerabilidades. También se ignoraban los hallazgos sin una versión corregida. Esto podía permitir el despliegue de imágenes con vulnerabilidades `HIGH` o `CRITICAL`, y un pipeline verde no servía como gate de seguridad.

## Decisión

- Escanear las ocho imágenes del commit con Trivy.
- Considerar bloqueantes las vulnerabilidades `HIGH` o `CRITICAL` que tengan una versión corregida disponible.
- Configurar `--severity HIGH,CRITICAL`, `--ignore-unfixed` y `--exit-code 1`.
- Mantener `allow_failure: false` explícito para que quede documentada la intención, aunque GitLab usa `false` como valor predeterminado.
- Conservar los reportes JSON como artifacts incluso cuando el job falle, para identificar imagen, CVE, paquete y versión afectados.
- No permitir que el deploy avance si Trivy falla. Remediar el hallazgo corregible y volver a ejecutar el pipeline. Los hallazgos sin parche se excluyen del reporte/umbral mediante `--ignore-unfixed` y no hacen fallar el job.

## Alternativas consideradas

- Omitir `allow_failure`: el comportamiento de GitLab sería equivalente porque el valor predeterminado es `false`, pero se prefiere explicitar la política en el job.
- Quitar `--ignore-unfixed`: se descarta para evitar bloquear el pipeline por vulnerabilidades sin corrección disponible; el gate se concentra en hallazgos que pueden remediarse.
- Mantener Trivy informativo con `allow_failure: true`: se descarta porque el pipeline podría llegar al deploy con hallazgos.

## Consecuencias

- Un hallazgo `HIGH` o `CRITICAL` con versión corregida bloquea el pipeline y el deploy automático.
- Las vulnerabilidades sin parche se excluyen del reporte y del umbral de fallo; por tanto, un pipeline verde no implica ausencia de vulnerabilidades sin fix conocido.
- Los cambios en la base de vulnerabilidades o en imágenes base pueden hacer aparecer findings en ejecuciones posteriores; la revisión debe vincularse al pipeline, tag y digest correspondientes.
- Los reportes se mantienen como artifacts para que el fallo sea diagnosticable y no oculte evidencia.
- El cambio puede dejar pipelines rojos hasta que se remedien los hallazgos existentes; esto es parte intencional de la política fail-closed.

## Referencias

- `.gitlab-ci.yml`
- `ANALISIS.md`
- `SEGURIDAD.md`
- [Runbook de Trivy](../runbooks/runbook-trivy-vulnerabilities.md)
- [Postmortem del hallazgo CVE](../postmortems/PM-2026-11-trivy-cve-discovery.md)
