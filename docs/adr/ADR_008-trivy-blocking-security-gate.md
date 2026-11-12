# ADR_008: Gate bloqueante de vulnerabilidades Trivy

- **Estado:** Aceptada
- **Fecha:** 2026-11-12
- **Decisores:** Grupo 19
- **Reemplaza:** [ADR_007](ADR_007-ci-testing-and-security-gates.md), únicamente en la política de tolerancia al fallo y umbral de Trivy.

## Contexto

La política anterior permitía que el pipeline continuara aunque Trivy detectara vulnerabilidades. También se ignoraban los hallazgos sin una versión corregida. Esto podía permitir el despliegue de imágenes con vulnerabilidades `HIGH` o `CRITICAL`, y un pipeline verde no servía como gate de seguridad.

## Decisión

- Escanear las ocho imágenes del commit con Trivy.
- Considerar bloqueante cualquier vulnerabilidad `HIGH` o `CRITICAL`, tenga o no una versión corregida.
- Configurar `--severity HIGH,CRITICAL` y `--exit-code 1`; no usar `--ignore-unfixed`.
- Mantener `allow_failure: false` explícito para que quede documentada la intención, aunque GitLab usa `false` como valor predeterminado.
- Conservar los reportes JSON como artifacts incluso cuando el job falle, para identificar imagen, CVE, paquete y versión afectados.
- No permitir que el deploy avance si Trivy falla. Remediar el hallazgo y volver a ejecutar el pipeline; los hallazgos sin parche también requieren investigación antes de continuar.

## Alternativas consideradas

- Omitir `allow_failure`: el comportamiento de GitLab sería equivalente porque el valor predeterminado es `false`, pero se prefiere explicitar la política en el job.
- Mantener `--ignore-unfixed`: se descarta porque deja fuera hallazgos `HIGH`/`CRITICAL` y no satisface el objetivo de bloquear ante cualquiera de esas severidades.
- Mantener Trivy informativo con `allow_failure: true`: se descarta porque el pipeline podría llegar al deploy con hallazgos.

## Consecuencias

- Un hallazgo `HIGH` o `CRITICAL` bloquea el pipeline y el deploy automático.
- Las vulnerabilidades sin parche también bloquean; pueden requerir coordinación con el mantenedor de la imagen o una actualización compatible, pero no se convierten en éxito silencioso.
- Los cambios en la base de vulnerabilidades o en imágenes base pueden hacer aparecer findings en ejecuciones posteriores; la revisión debe vincularse al pipeline, tag y digest correspondientes.
- Los reportes se mantienen como artifacts para que el fallo sea diagnosticable y no oculte evidencia.
- El cambio puede dejar pipelines rojos hasta que se remedien los hallazgos existentes; esto es parte intencional de la política fail-closed.

## Referencias

- `.gitlab-ci.yml`
- `ANALISIS.md`
- `SEGURIDAD.md`
- [Runbook de Trivy](../runbooks/runbook-trivy-vulnerabilities.md)
- [Postmortem del hallazgo CVE](../postmortems/PM-2026-11-trivy-cve-discovery.md)
