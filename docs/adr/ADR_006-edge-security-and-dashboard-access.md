# ADR_006: Seguridad en el borde, TLS y dashboard

- **Estado:** Aceptada para el entorno académico
- **Fecha:** 2026-11-11
- **Decisores:** Grupo 19

## Contexto

La aplicación debe exponerse mediante HTTPS, mantener la base y las APIs fuera de puertos públicos y proteger el dashboard administrativo. AWS Academy renueva IP, instancia, key pair y credenciales entre sesiones, lo que dificulta operar con certificados y hosts permanentes.

## Decisión

- Publicar externamente HTTPS/443 en el Security Group y restringir SSH/22 a la IPv4 `/32` de salida del runner.
- No publicar HTTP/80, MariaDB ni los puertos de las APIs.
- Terminar TLS en Traefik con certificado autofirmado generado por el job de despliegue para la IP actual.
- Proteger el dashboard de Traefik con BasicAuth. El archivo con el hash se genera durante el deploy y se instala para que el UID 65532 de Traefik pueda leerlo.
- En Terraform, generar una clave Ed25519 efímera por ejecución; enviar a AWS solamente la clave pública y eliminar la privada del runner mediante `trap`.
- Mantener las credenciales de aplicación, AWS y Terraform State en variables de GitLab, no en el repositorio ni en las imágenes.

## Alternativas consideradas

- Certificado público con DNS estable: mejor validación de identidad, pero el entorno del Lab ofrece IP dinámica y no se dispone de DNS/certificado estable para cada sesión.
- Exponer la DB o APIs directamente: descartado porque no es necesario para la arquitectura ni el uso de la aplicación.
- Clave SSH persistente compartida: descartada para el modo Terraform porque una clave efímera limita su vigencia al job y evita conservar la privada en GitLab.

## Consecuencias y riesgos aceptados

- El certificado autofirmado cifra el tráfico, pero los navegadores no pueden validar una cadena de confianza pública y mostrarán una advertencia. No es adecuado para producción.
- BasicAuth protege el dashboard; las APIs de negocio no cuentan con autenticación de usuario en el proxy actual. El Security Group permite HTTPS público, por lo que las rutas de APIs son accesibles públicamente según su funcionalidad. Esto es una limitación del alcance académico, no un control de autorización completo.
- Restringir SSH a la IP del runner requiere mantener actualizado `RUNNER_EGRESS_CIDR` por sesión y disponer de un runner con egress estable/conocido.
- El montaje del socket Docker en Traefik es necesario para el provider Docker actual, pero concede acceso de alto privilegio al daemon; evaluar una API proxy limitada o provider de archivos en futuras mejoras.
- No registrar certificados privados, `.env`, hashes BasicAuth ni claves SSH en artifacts/logs.

## Referencias

- `infra/aws/main.tf` (Security Group, metadata y disco cifrado)
- `infra/aws/variables.tf` (`runner_ssh_cidr`, `ssh_public_key`)
- `docker-compose.yml` (443 y montajes de socket/certs/secrets)
- `traefik/dynamic/dashboard.yml`
- `scripts/deploy-ci.sh`
- `SEGURIDAD.md`
