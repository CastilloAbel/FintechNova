# Scripts operativos

Esta carpeta contiene los scripts ejecutados por una persona o por el pipeline desde la raíz del repositorio. Los scripts se ubican aquí para separar operaciones del código de las APIs.

| Script | Uso |
|---|---|
| [build.sh](build.sh) | Construcción/publicación histórica de las ocho imágenes en Docker Hub. |
| [build-ci.sh](build-ci.sh) | Constructor genérico para registry; acepta registry, tag y base de referencia. |
| [prepare-deploy.sh](prepare-deploy.sh) | Genera localmente el certificado TLS y agrega un usuario BasicAuth al archivo ignorado `secrets/dashboard_users`. |
| [setup-ec2.sh](setup-ec2.sh) | Prepara Docker y Compose en Amazon Linux 2023; CI lo copia a EC2 y lo ejecuta allí. |
| [deploy.sh](deploy.sh) | En EC2, valida los archivos runtime, inicia Compose con imágenes ya cargadas y ejecuta health checks HTTPS. `deploy-ci.sh` lo copia al directorio remoto como `deploy.sh`. |
| [deploy-ci.sh](deploy-ci.sh) | Helper del job `deploy_terraform`: transfiere imágenes/configuración y ejecuta el despliegue compartido. Se invoca desde `.gitlab-ci.yml` como `bash scripts/deploy-ci.sh`. |
| [find-vulnerabilities.ps1](find-vulnerabilities.ps1) | Resume hallazgos HIGH/CRITICAL de artifacts Trivy descargados; requiere `jq.exe`. |

## Ejecución desde la raíz del repositorio

Ejemplos de procedimientos históricos:

```sh
bash scripts/build.sh <DOCKER_USER> <IMAGE_TAG>
bash scripts/prepare-deploy.sh <usuario-dashboard>
```

Los scripts de tests y de inicialización requeridos por los componentes quedan en sus directorios, por ejemplo `aplicaciones-contenedores/api-tarjetas/tests/smoke.sh` y `aplicaciones-contenedores/db/init-scripts/`. No moverlos fuera de sus contextos: los Dockerfiles o el pipeline los referencian directamente.
