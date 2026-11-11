# ADR_002: Terraform para aprovisionar AWS

- **Estado:** Aceptada
- **Fecha:** 2026-11-11
- **Decisores:** Grupo 19

## Contexto

El despliegue requiere preparar una EC2 de AWS Academy, un Security Group y una clave SSH, y repetir el proceso al renovar el entorno temporal del laboratorio. La configuración manual hace difícil reproducir la infraestructura y vincularla al commit que se despliega.

## Decisión

Definir y administrar la infraestructura con Terraform en `infra/aws/`, ejecutado por el job GitLab CI `deploy_terraform`. El state se almacena en el backend HTTP de GitLab con nombre fijo `fintech-nova-sandbox`. El job crea una clave Ed25519 efímera por ejecución y entrega a AWS únicamente su clave pública.

La EC2 usa Amazon Linux 2023, tipo `t3.small`, disco raíz gp3 cifrado de 20 GiB, IMDSv2 obligatorio y una subred predeterminada seleccionada por Terraform. El Security Group permite SSH desde el CIDR IPv4 `/32` del runner y HTTPS público en 443; la salida es abierta para instalación de paquetes, transferencia de imágenes e integraciones de la aplicación.

## Alternativas consideradas

- Aprovisionamiento manual en la consola: simple para una prueba aislada, pero difícil de reproducir y auditar.
- Crear un state por pipeline: separaría los despliegues, pero acumularía instancias y consumiría rápidamente cuotas del Sandbox.
- Terraform local o state dentro del workspace del runner: no compartiría estado de manera confiable entre pipelines.

## Consecuencias

- Las variables AWS temporales y las credenciales de escritura del backend deben estar disponibles y protegidas en GitLab antes del pipeline de `main`.
- El primer `terraform init` del despliegue valida el acceso al backend; no se mantiene un job de probe independiente.
- Como se comparte el state, un apply sucesivo reconcilia el mismo conjunto de recursos. El sufijo/key pair variable puede provocar el reemplazo de la instancia.
- El disco tiene `delete_on_termination = true`; reemplazar o terminar la EC2 elimina el volumen raíz y la base de datos local. El flujo no sirve como almacenamiento durable y los datos requeridos deben respaldarse externamente.
- Se decidió no ofrecer un job `destroy_ec2` en CI. AWS Academy puede expirar o resetear recursos al vencer la sesión.
- El recurso de subnet depende de que la cuenta/región tenga VPC y subnets predeterminadas. Una evolución podría parametrizar VPC/subnet o definirlas explícitamente.

## Referencias

- `infra/aws/main.tf`
- `infra/aws/variables.tf`
- `infra/aws/outputs.tf`
- `infra/aws/versions.tf`
- `.gitlab-ci.yml`
- `DEPLOY.md`
