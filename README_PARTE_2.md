# FinTech Nova — Parte 2: Integración y despliegue continuo

**Grupo 19 · Camila Gea (82327) · Abel Castillo (90322)**

## Objetivo

En esta etapa se incorporó GitLab CI/CD para validar el proyecto, construir y publicar sus imágenes, ejecutar controles de seguridad y facilitar el despliegue en AWS EC2. El pipeline complementa los procedimientos manuales de la Parte 1 y conserva los scripts existentes para su uso histórico.

La arquitectura desplegada continúa formada por ocho servicios: Traefik, MariaDB, una interfaz web y cinco APIs independientes. El acceso externo se realiza mediante HTTPS en el puerto 443; las APIs y la base de datos se comunican por la red interna de Docker.

## Flujo del pipeline

El orden de stages definido en `.gitlab-ci.yml` es `test` → `build` → `security` → `deploy`.

| Stage | Jobs y propósito |
|---|---|
| `test` | `prueba_pipeline` comprueba la ejecución básica del pipeline. `validar_terraform` ejecuta `fmt` y `validate` sobre `infra/aws`; no aprovisiona recursos ni comprueba el backend remoto. |
| `build` | Ocho jobs independientes construyen y publican en GitLab Container Registry las imágenes de Traefik, MariaDB, las cinco APIs y Web. Se etiqueta cada versión con el SHA corto del commit y también se actualiza `latest`. |
| `security` | `validar_compose`, Hadolint, Semgrep, Trivy, Yamllint y Gitleaks revisan configuración, Dockerfiles, código, imágenes y secretos. Los reportes disponibles se publican como artifacts. |
| `deploy` | Ofrece dos jobs manuales según la rama: `deploy_aws` para una instancia existente y `deploy_terraform` para una instancia gestionada por Terraform. |

Los jobs de build pueden correr en paralelo según la capacidad de los runners. Los despliegues ocurren después de completar las etapas previas. Ambos cargan las imágenes en EC2 desde el runner mediante `docker save` y `docker load`, ya que el `deploy.sh` actual usa `docker compose up --pull never` y no descarga imágenes desde el registry.

## Dos rutas manuales de despliegue

Los jobs representan destinos diferentes, con credenciales y claves SSH separadas. No deben configurarse para desplegar a la misma instancia; tampoco deben ejecutarse simultáneamente contra un mismo host.

| Job | Modo | Ramas | Variables y destino |
|---|---|---|---|
| `deploy_aws` | Despliega sobre una EC2 ya existente. Prepara Docker/Compose, transfiere las imágenes y archivos runtime, ejecuta `deploy.sh` y sus verificaciones. No crea ni termina la instancia. | `main`, `feature/deploy-aws`, `feature/test-deploy-ec2` | `AWS_EC2_HOST` (IPv4), `AWS_EC2_USER` y `AWS_SSH_PRIVATE_KEY` (variable de archivo), además de credenciales de aplicación y Registry. |
| `deploy_terraform` | Inicializa Terraform, genera una clave efímera, aprovisiona o actualiza infraestructura, y luego utiliza el mismo flujo de despliegue de aplicación. | `main`, `deploy/terraform` | Credenciales temporales de AWS Academy, `RUNNER_EGRESS_CIDR`, autenticación del state HTTP y credenciales de aplicación/Registry. No usa el host ni la clave SSH del modo legacy. |

### Flujo compartido de aplicación

Para reducir duplicación, ambos jobs invocan el script raíz [deploy-ci.sh](deploy-ci.sh). Este helper:

1. Valida las variables requeridas, la IP IPv4 del host, el usuario del dashboard y el archivo de clave SSH.
2. Prepara `known_hosts` y una configuración SSH temporal con verificación estricta de host.
3. Ejecuta `setup-ec2.sh` en la instancia.
4. Inicia sesión en GitLab Container Registry, descarga las ocho imágenes del commit y las carga en EC2.
5. Copia Compose y `deploy.sh`, genera `.env`, el hash de BasicAuth y el certificado TLS, y transfiere esos archivos runtime.
6. Ejecuta `deploy.sh`, que exige los ocho contenedores activos y respuestas HTTPS esperadas para la web, las APIs y el dashboard.
7. Solo tras completar correctamente las verificaciones muestra `https://<IP>/` y `https://<IP>/dashboard/`.

Terraform mantiene aparte su `init`, `plan` y `apply`; el modo legacy proporciona el host y la clave ya existentes. Los archivos temporales del runner se crean con permisos restrictivos y se eliminan mediante `trap`, incluso si el helper falla. Los archivos runtime transferidos a EC2 no se borran porque los necesita el servicio.

## State y ciclo de vida Terraform

`deploy_terraform` utiliza el state HTTP fijo `fintech-nova-sandbox`; no se crea un state por pipeline. El sufijo y el key pair cambian entre ejecuciones, por lo que un apply sucesivo puede reemplazar la instancia registrada en ese state, en lugar de acumular instancias independientes. La instancia usa un disco raíz EBS con `delete_on_termination`; si se reemplaza, se pierde el disco y la base de datos local. Respaldar cualquier dato necesario antes de un nuevo apply.

El pipeline no incluye `terraform_state_probe`, `destroy_ec2` ni una etapa de cleanup. El primer `terraform init` dentro de `deploy_terraform` comprueba el acceso al backend. No hay un botón de CI para terminar EC2; AWS Academy puede expirar o resetear los recursos al vencer la sesión. Si el state antiguo `fintech-state-probe` aún existe, verificar que sea el state de prueba antes de eliminarlo manualmente desde GitLab.

## Controles de seguridad y política

| Herramienta/job | Alcance | Comportamiento actual |
|---|---|---|
| Docker Compose (`validar_compose`) | Sintaxis y configuración de Compose | Falla ante errores de configuración. |
| Hadolint (`analizar_dockerfiles`) | Los ocho Dockerfiles | El umbral `error` determina los hallazgos que fallan el job. |
| Semgrep (`analizar_codigo_semgrep`) | Código, Dockerfiles y configuración | Considera errores de severidad `ERROR`; genera reporte JSON. |
| Trivy (`analizar_imagenes_trivy`) | Las ocho imágenes del commit | Examina `HIGH` y `CRITICAL`, ignora las no corregibles y genera reportes JSON. Tiene `allow_failure: true`: es informativo y su fallo no bloquea el pipeline ni los deploys manuales. |
| Yamllint (`analizar_archivos_yaml`) | `.gitlab-ci.yml`, Compose y configuración YAML de Traefik | Falla ante problemas detectados por la configuración del job. |
| Gitleaks (`detectar_secretos`) | Árbol del repositorio | Busca secretos y genera un reporte redactado. |

Los artifacts de análisis se conservan según la configuración del pipeline. La política efectiva no presenta Trivy como un gate: sus resultados deben revisarse, pero un pipeline verde no prueba por sí solo que las imágenes estén libres de vulnerabilidades. Los hallazgos de los controles configurados como obligatorios sí pueden impedir el avance.

## Variables de CI/CD

Configurar los secretos en **Settings → CI/CD → Variables**; usar variables protegidas y enmascaradas cuando corresponda. Nunca incorporar credenciales reales, claves privadas ni `.env` al repositorio.

| Grupo | Variables principales |
|---|---|
| Deploy legacy | `AWS_EC2_HOST`, `AWS_EC2_USER`, `AWS_SSH_PRIVATE_KEY` como variable de archivo. |
| Terraform/AWS Academy | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_DEFAULT_REGION`, `RUNNER_EGRESS_CIDR`. Renovar las credenciales temporales al iniciar cada sesión del Lab. |
| State de Terraform | `TF_STATE_USERNAME`, `TF_STATE_PASSWORD`. El backend permanece en `fintech-nova-sandbox`. |
| Aplicación | `DB_USER`, `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `DASHBOARD_USER`, `DASHBOARD_PASSWORD` y, si aplica, `IPAPI_TOKEN`. |
| Registry | Variables automáticas de GitLab `CI_REGISTRY`, `CI_REGISTRY_USER` y `CI_REGISTRY_PASSWORD`. |

Las variables protegidas solo están disponibles en ramas protegidas. Revisar la configuración de ramas y variables antes de ejecutar el job manual correspondiente.

## Scripts y documentación relacionada

Se preservan los scripts históricos `build.sh`, `build-ci.sh`, `prepare-deploy.sh`, `setup-ec2.sh` y `deploy.sh`. Los jobs de GitLab construyen las imágenes con sus plantillas CI; el helper [deploy-ci.sh](deploy-ci.sh) comparte únicamente la fase de transferencia y despliegue y no reemplaza esos scripts históricos.

- [README.md](README.md): arquitectura, implementación, pruebas y resumen de las dos rutas.
- [DEPLOY.md](DEPLOY.md): variables, instrucciones operativas y procedimiento de cada modo.
- [AWS_EC2.md](AWS_EC2.md): configuración y evidencias históricas de EC2.
- [SEGURIDAD.md](SEGURIDAD.md) y [ANALISIS.md](ANALISIS.md): controles, riesgos y resultados de seguridad.
- [ERRORES.md](ERRORES.md): incidencias y soluciones documentadas.

## Tests automáticos agregados (API Clientes)

El job `test_api_clientes` ejecuta tres pruebas con `unittest` y el cliente de pruebas de Flask **antes de Build**: salud (`GET /` → 200), listado simulado de clientes (`GET /clientes` → 200) y cliente inexistente (`GET /clientes/999` → 404). La conexión a MariaDB se simula mediante `unittest.mock`, por lo que el job no necesita una base real ni credenciales. Si falla una prueba, el job falla y no avanza a Build. No reemplaza las verificaciones HTTPS posteriores al despliegue.

Para ejecutarlas localmente: `cd aplicaciones-contenedores/api-clientes`, instalar `requirements.txt` y correr `python -m unittest discover -s tests -p 'test_*.py' -v`.

## Evidencias de la Parte 2 y Terraform

- [Extracto del despliegue exitoso del 9/11/2026](docs/evidencias/parte-2-despliegue-terraform.md): ocho contenedores activos, base healthy y siete verificaciones HTTPS con el tag `9e4ea77f`.
- Capturas de Parte 1: conservadas en `docs/evidencias/`, **no corresponden a la última sesión Terraform**.
- **Pendiente antes de entregar:** agregar capturas reales de la misma sesión de AWS Academy para el pipeline completo, job `deploy_terraform` (incluyendo `terraform apply`), EC2 creada y aplicación abierta en HTTPS. Guardarlas en `docs/evidencias/` y enlazarlas aquí.

Nota: Terraform está integrado como ruta alternativa de aprovisionamiento. El job `deploy_terraform` se inicia manualmente; luego aprovisiona y ejecuta el despliegue automáticamente.
