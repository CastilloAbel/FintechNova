# Runbooks operativos

Procedimientos paso a paso para operar el pipeline y responder a resultados habituales. Antes de ejecutar cualquier procedimiento, comprobar que se está en el proyecto, rama y pipeline correctos. No incluir valores secretos en comandos, capturas ni reportes versionados.

| Runbook | Uso |
|---|---|
| [Despliegue en AWS Academy](runbook-deploy-aws-academy.md) | Preparar credenciales y ejecutar el deploy automático después de integrar a `main`. |
| [Revisión y remediación de Trivy](runbook-trivy-vulnerabilities.md) | Interpretar artifacts, priorizar CVEs y verificar la corrección en imágenes nuevas. |
| [Diagnóstico de pipeline fallido](runbook-pipeline-failure.md) | Investigar fallas por stage sin saltarse controles ni desplegar una versión no validada. |
