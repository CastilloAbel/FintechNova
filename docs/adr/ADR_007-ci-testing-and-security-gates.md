# ADR_007: Validación y política de controles en CI

> Esta decisión describe la política histórica aceptada el 2026-11-11. Fue reemplazada por ADR_008; no describe la configuración vigente.

- **Estado:** Reemplazada por [ADR_008](ADR_008-trivy-blocking-security-gate.md)
- **Fecha:** 2026-11-11
- **Decisores:** Grupo 19

## Contexto

El proyecto combina cinco APIs con lenguajes distintos, imágenes Docker y configuración de infraestructura. Se necesita detectar errores antes de publicar y desplegar, y conservar evidencia para revisar hallazgos. El pipeline debe equilibrar feedback rápido, recursos limitados del runner y la política de severidad acordada.

## Decisión

- Mantener stages `test`, `build`, `security` y `deploy`.
- Ejecutar pruebas específicas por API en la etapa `test`, de manera independiente cuando sea posible; validar Compose y formato/configuración Terraform antes de despliegue.
- Construir las ocho imágenes en jobs separados y paralelos.
- Ejecutar Semgrep, Hadolint, Yamllint, Gitleaks y Trivy en `security`, guardando reportes como artifacts cuando está configurado.
- Tratar hallazgos Semgrep `ERROR` y errores de los controles obligatorios como bloqueantes.
- Mantener Trivy con `allow_failure: true`: revisa `HIGH`/`CRITICAL` corregibles, pero es informativo y no bloquea el pipeline. Los artifacts deben revisarse; un pipeline verde no demuestra ausencia de vulnerabilidades.
- Ejecutar el despliegue automático solo después del éxito de los stages anteriores en `main`.

## Alternativas consideradas

- Un único job secuencial de pruebas/build: más sencillo, pero alarga el feedback y reduce el paralelismo.
- Hacer fallar el pipeline ante cualquier hallazgo Trivy desde el inicio: más estricto, pero se decidió primero revisar las líneas base y mantener explícitamente la política informativa.
- Ignorar los hallazgos de Trivy sin generar reportes: se descarta porque eliminaría evidencia para evaluar y corregir riesgos.

## Consecuencias

- Las pruebas y builds paralelos mejoran el tiempo de feedback, sujetos a disponibilidad de runners.
- Los stages bloqueantes impiden que una falla de test, build o control obligatorio llegue al deploy.
- Trivy puede fallar sin impedir el deploy; el equipo debe revisar manualmente el resultado y registrar aceptación/remediación de riesgos.
- Las imágenes de herramientas indicadas como `latest` pueden cambiar entre ejecuciones; una mejora futura es fijar versiones/digests después de acordar el mantenimiento de upgrades.
- El despliegue se activa tras el pipeline `push` de `main`; para que sea exclusivo a merges `feat/*`, la rama debe protegerse y los MRs deben validar su rama de origen.

## Referencias

- `.gitlab-ci.yml`
- `ANALISIS.md`
- `SEGURIDAD.md`
- `README_PARTE_2.md`
