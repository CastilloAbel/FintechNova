# GitHub Actions: migración de CI/CD

## Estado de implementación

El workflow inicial está en `.github/workflows/ci.yml`. El archivo `.gitlab-ci.yml` se conserva sin cambios como referencia histórica. No se debe asumir que los secretos estén ya configurados ni ejecutar el deploy hasta completar los requisitos manuales de esta guía.

| Stage | Qué ejecuta |
|---|---|
| `test` | Pruebas de las cinco APIs, Terraform sin backend remoto y validación de rama para PRs a `main`. |
| `build` | En PRs y ramas `feature/**`, construye localmente las ocho imágenes sin publicarlas. En un push a `main`, las publica en GHCR con tag corto del commit y `latest`. |
| `security` | Compose, Hadolint, Semgrep, Yamllint, actionlint, Gitleaks y Trivy. En PRs Trivy construye/analiza imágenes locales; en `main` analiza los tags publicados en GHCR. Los hallazgos Trivy `HIGH`/`CRITICAL` corregibles bloquean. Los reportes configurados se guardan siete días. |
| `deploy` | Solo en push a `main`, después del éxito de los otros stages. Usa Terraform y el state HTTP existente de GitLab; transfiere imágenes por SSH a EC2. |

No se usa `pull_request_target`; los PRs no reciben secretos y no tienen permiso de escritura en GHCR. El deploy usa el `GITHUB_TOKEN` efímero, sin crear un PAT de GitHub. `feature/migrate-github` activará validaciones y no desplegará.

## Configuración manual requerida

### 1. GitLab: conservar acceso al Terraform State

1. Abre el proyecto GitLab anterior y copia su Project ID numérico desde **Settings → General**.
2. Si es GitLab.com, la URL base de API es `https://gitlab.com/api/v4`. En una instancia propia, usa la URL de API de esa instancia.
3. En **Settings → Access tokens**, verifica el Project Access Token existente: debe estar activo y no vencido, tener scope `api` y un rol con acceso al Terraform State HTTP. Identifica el username del bot asociado.
4. Guarda el token únicamente como secreto en GitHub. No lo compartas por chat, no lo imprimas y no lo guardes en el repositorio.
5. No borres ni archives el proyecto o el state `fintech-nova-sandbox`. El state debe seguir accesible en el endpoint `/projects/<PROJECT_ID>/terraform/state/fintech-nova-sandbox`, incluyendo lock/unlock.

GitLab.com requiere Premium o Ultimate para crear nuevos Project Access Tokens. Si el existente no funciona, está vencido o no se puede rotar con el plan actual, detenerse antes del deploy y resolver una credencial compatible. No se debe sustituir a ciegas ni cambiar de backend.

### 2. GitHub: variables de Actions

En el repositorio, ve a **Settings → Secrets and variables → Actions → Variables** y agrega:

| Variable | Valor |
|---|---|
| `GITLAB_API_V4_URL` | URL base API V4, p. ej. `https://gitlab.com/api/v4` |
| `GITLAB_PROJECT_ID` | ID numérico copiado del proyecto GitLab que guarda el state |
| `AWS_DEFAULT_REGION` | Región activa del Learner Lab, donde existe la AMI |
| `AWS_EC2_AMI_ID` | Opcional; configurar solo si la AMI predeterminada `ami-0c230065b91270bc6` no corresponde a esa región |

### 3. GitHub: entorno y secretos

En **Settings → Environments**, crea el entorno `aws-sandbox`. En sus **Environment secrets**, registra:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `TF_STATE_USERNAME` (username del bot del token de GitLab)
- `TF_STATE_PASSWORD` (Project Access Token existente)
- `DB_USER`
- `DB_PASSWORD`
- `MYSQL_ROOT_PASSWORD`
- `DASHBOARD_USER`
- `DASHBOARD_PASSWORD`
- `IPAPI_TOKEN` (solo si se usa la integración)

Los secretos del entorno solo se usan en el job de deploy, que se limita a push a `main`. Actualiza las credenciales temporales de AWS Academy antes de cada despliegue. El workflow valida que las obligatorias estén presentes, pero no puede validar su vigencia hasta contactar AWS o GitLab.

No es necesario duplicar `CI_REGISTRY_*`, `CI_COMMIT_*`, `CI_PROJECT_*`, `IMAGE_TAG`, `RUNNER_EGRESS_CIDR` ni tags de runners de GitLab. GitHub proporciona el contexto de commit, y el workflow calcula GHCR y el egress del runner.

### 4. Permisos de Actions, GHCR y rama principal

1. En **Settings → Actions → General**, confirma que GitHub Actions esté permitido.
2. GHCR recibe permisos mínimos por job: `packages: write` para publicar en `main` y `packages: read` para Trivy/deploy. Comprueba en la página del package GHCR que el paquete esté asociado al repositorio y que Actions tenga acceso. Si el package se mantiene privado, el token integrado debe poder leerlo; no configures credenciales en EC2.
3. Protege `main` mediante reglas de rama/rulesets: exigir PR, impedir pushes directos y requerir que pase el workflow. Las ramas de trabajo deben llamarse `feature/<nombre>`.
4. Una vez verificados los nombres exactos de los checks en la primera ejecución, agrégalos a los checks obligatorios de protección de rama. Evita requerir el check `deploy`, porque las ejecuciones de PR no despliegan.

## Egress SSH y primera ejecución

El workflow consulta el egress IPv4 actual del runner y Terraform aplica una regla SSH `/32`; HTTPS 443 sigue público. No se abre SSH a `0.0.0.0/0`. Si la consulta externa del egress falla, el deploy falla de forma cerrada.

**Antes de habilitar un push/merge a `main`:**

- Confirma que las credenciales AWS Academy están vigentes y el Lab está activo.
- Verifica la región, AMI, cuota del Sandbox y recursos que se crearán.
- Comprueba que GitLab no tenga otro pipeline de deploy concurrente; su lock HTTP de Terraform debe seguir habilitado.
- Recuerda que el sufijo y el key pair cambian por ejecución: Terraform puede reemplazar EC2 y borrar el disco root. Se acepta este comportamiento para la migración; la base MariaDB local y demás datos de esa instancia pueden perderse en cada deploy.
- Revisa los logs y artifacts para confirmar que no aparezcan tokens, claves privadas, `.env` o contraseñas.

Primero empuja la rama de migración y valida los jobs de test/build/security. Ese push no debe desplegar ni publicar paquetes GHCR. La primera publicación en GHCR y el primer deploy solo ocurren cuando un cambio llega a `main` y todas las etapas anteriores pasan.

## Costos y límites

Con un repositorio público, los runners estándar de GitHub Actions son actualmente gratuitos. GitHub Container Registry indica que el almacenamiento y transferencia de Container Registry son actualmente gratuitos; las políticas pueden cambiar. Los reportes de Actions se retienen siete días para limitar almacenamiento. AWS no queda cubierto por ello: confirma que el uso esté dentro de AWS Academy y sus cuotas. No activar un deploy con cargo AWS que no hayas aprobado.

## GitLab CI tras validar la migración

No se modifica `.gitlab-ci.yml`. Después de demostrar que Actions puede leer, escribir y bloquear/desbloquear el state, desactiva en GitLab los schedules, triggers, webhooks y runners CI que puedan producir un segundo deploy. Hazlo sin borrar el proyecto GitLab ni el state y verifica otra vez el acceso HTTP al state. El `.gitlab-ci.yml` queda como registro histórico; no debe quedar otro pipeline aplicando ese state en paralelo.
