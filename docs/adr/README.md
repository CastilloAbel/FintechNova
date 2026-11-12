# Architecture Decision Records

Este directorio registra decisiones de arquitectura y operación relevantes de FinTech Nova. Los ADRs documentan el contexto, decisión, alternativas y consecuencias para que futuras modificaciones puedan entender por qué se eligió el diseño actual.

## Índice

| ADR | Decisión |
|---|---|
| [ADR_001](ADR_001-traefik-reverse-proxy.md) | Traefik como proxy inverso y terminador TLS; desviación documentada respecto de la referencia NGINX del enunciado. |
| [ADR_002](ADR_002-terraform-aws-infrastructure.md) | Terraform, state remoto de GitLab y ciclo de vida de EC2 en AWS Academy. |
| [ADR_003](ADR_003-gitlab-ci-release-and-deployment-policy.md) | Validaciones CI, ramas `feat/*` y deploy automático después del push a `main`. |
| [ADR_004](ADR_004-gitlab-container-registry-image-delivery.md) | GitLab Container Registry, tags por commit y transferencia de imágenes desde el runner. |
| [ADR_005](ADR_005-shared-mariadb-and-ephemeral-persistence.md) | MariaDB compartida, bases lógicas por API y persistencia efímera en EC2. |
| [ADR_006](ADR_006-edge-security-and-dashboard-access.md) | Exposición de red, TLS autofirmado, SSH efímero y protección del dashboard. |
| [ADR_007](ADR_007-ci-testing-and-security-gates.md) | Decisión histórica de pruebas paralelas y Trivy informativo; reemplazada por ADR_008. |
| [ADR_008](ADR_008-trivy-blocking-security-gate.md) | Gate bloqueante de Trivy para vulnerabilidades `HIGH` y `CRITICAL` corregibles; ignora las no corregibles. |

## Convención

- Numerar ADRs secuencialmente y usar el formato `ADR_NNN-descripcion-corta.md`.
- Mantener las decisiones aceptadas como registro histórico; si cambian, crear un ADR nuevo que las reemplace en lugar de reescribir el razonamiento anterior.
- Estados recomendados: Propuesta, Aceptada, Rechazada, Reemplazada.
