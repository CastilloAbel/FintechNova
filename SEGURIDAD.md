# Seguridad

Este documento describe las medidas de seguridad implementadas para el despliegue de FinTech Nova.

## 1. Acceso mediante HTTPS

La aplicación se publica externamente únicamente mediante HTTPS.

El único puerto público utilizado por la aplicación es:

```text
443/TCP
```

Traefik funciona como reverse proxy y punto de entrada a la arquitectura.

El flujo de una solicitud es:

```text
Internet
   |
HTTPS :443
   |
Traefik
   |
   +---- Web
   +---- API Clientes
   +---- API Pagos
   +---- API Facturas
   +---- API Transacciones
   +---- API Tarjetas
```

Las comunicaciones desde Traefik hacia los servicios se realizan dentro de la red privada de Docker.

Las APIs y MariaDB no publican sus puertos directamente hacia Internet.

---

## 2. Terminación TLS

La terminación TLS se realiza en Traefik.

Esto significa que Traefik recibe las conexiones HTTPS provenientes del usuario, utiliza el certificado configurado y luego enruta las solicitudes hacia el servicio correspondiente dentro de la red Docker.

De esta forma se centraliza el acceso HTTPS en un único punto.

---

## 3. Certificado autofirmado

Para el Trabajo Práctico se utiliza un certificado TLS autofirmado.

Los archivos utilizados son:

```text
certs/local.crt
certs/local.key
```

El certificado y la clave se montan en el contenedor de Traefik durante el despliegue.

Al tratarse de un certificado autofirmado, el navegador muestra una advertencia indicando que no puede verificar la autoridad emisora.

Esto es esperado para este entorno académico y no significa que la aplicación esté utilizando HTTP.

Para las pruebas automatizadas se utiliza:

```sh
curl -k
```

La opción `-k` permite realizar la prueba HTTPS sin exigir que el certificado haya sido firmado por una autoridad certificadora reconocida.

En un entorno productivo se debería utilizar un certificado emitido por una autoridad certificadora confiable.

El certificado y su clave se generan localmente antes de transferir los archivos a EC2 mediante `prepare-deploy.sh`. El certificado usa el CN fijo `*.19.grupo.devops.frc.utn.edu.ar`; la clave privada se guarda con permisos restrictivos y no se versiona. Cada ejecución reemplaza el par anterior.

---

## 4. Puerto HTTP 80

El puerto HTTP `80` no se publica en el host ni se habilita como puerto de acceso a la aplicación en el Security Group de AWS.

El acceso externo se realiza exclusivamente mediante:

```text
HTTPS :443
```

Aunque la imagen base de Traefik pueda declarar internamente otros puertos, Docker Compose solamente publica el puerto `443` del contenedor hacia la instancia EC2.

---

## 5. Red interna de Docker

Todos los servicios pertenecen a la red Docker:

```text
proxy
```

Dentro de esta red los contenedores pueden comunicarse utilizando sus nombres de servicio.

Por ejemplo, las APIs acceden a MariaDB mediante:

```text
DB_HOST=tp1-db
DB_PORT=3306
```

No es necesario publicar el puerto `3306` de MariaDB hacia Internet.

Esto permite mantener la base de datos aislada del acceso externo.

---

## 6. Variables de entorno

Las credenciales y valores sensibles no se almacenan directamente dentro del código fuente.

Se utiliza un archivo:

```text
.env
```

Entre las variables administradas se encuentran:

```text
DB_USER
DB_PASSWORD
MYSQL_ROOT_PASSWORD
IPAPI_TOKEN
DOMAIN
```

El archivo `.env` no debe versionarse.

Para documentar las variables requeridas se utiliza:

```text
env.example
```

Este archivo contiene la estructura necesaria pero no las credenciales reales.

---

## 7. Token de la API externa

La API de Transacciones utiliza un servicio externo para obtener información geográfica a partir de una dirección IP.

El token correspondiente se obtiene mediante:

```text
IPAPI_TOKEN
```

La aplicación Go lee el valor desde una variable de entorno.

De esta manera el token no queda escrito directamente en:

- el código fuente;
- el Dockerfile;
- la imagen Docker;
- el repositorio Git.

---

## 8. Dashboard de Traefik

El dashboard de Traefik se encuentra disponible mediante:

```text
/dashboard/
```

El dashboard no es de acceso público sin autenticación.

Se utiliza un middleware `BasicAuth` y las credenciales se leen desde:

```text
/run/secrets/dashboard_users
```

El archivo correspondiente se encuentra localmente en:

```text
secrets/dashboard_users
```

y no debe almacenarse públicamente en el repositorio.

El usuario se agrega con `prepare-deploy.sh`; la contraseña se solicita sin mostrarla y se envía por entrada estándar a `htpasswd` dentro de un contenedor `httpd:2.4`. El archivo guarda el hash, no la contraseña en texto claro. Cada usuario distinto se agrega en una nueva línea; los nombres repetidos se rechazan.

Por lo tanto, una solicitud al dashboard sin credenciales debe recibir una respuesta de autenticación requerida.

El script de verificación comprueba este comportamiento.

---

## 9. Security Group de AWS

La instancia EC2 utilizada para el despliegue permite únicamente los accesos externos necesarios.

Reglas de entrada:

```text
SSH     TCP 22    -> IP autorizada
HTTPS   TCP 443   -> 0.0.0.0/0
```

El puerto SSH `22` se restringe a la dirección IP utilizada para la administración de la instancia.

El puerto `443` se encuentra disponible públicamente para permitir el acceso a la aplicación.

No se configura una regla pública para:

```text
80
3306
8080
8083
8084
8085
```

Por lo tanto, la base de datos y las APIs no pueden accederse directamente desde Internet.

---

## 10. Acceso SSH

El acceso administrativo se realiza mediante claves SSH que permanecen en el runner/PC y nunca se copian a EC2. El pipeline separa dos destinos y credenciales: `deploy_aws` usa la clave de archivo `AWS_SSH_PRIVATE_KEY` para una instancia existente; `deploy_terraform` genera una clave Ed25519 efímera para otra instancia y elimina su copia privada al finalizar.

La clave privada:

- no se almacena en Git;
- no se incluye en las imágenes Docker;
- no se copia dentro del proyecto;
- debe conservar permisos restringidos.

Durante las pruebas desde WSL fue necesario almacenar una copia de la clave en el directorio personal y asignarle:

```sh
chmod 600 ~/FinTech-Nova.pem
```

La clave se utiliza únicamente para establecer conexiones `ssh` y copiar archivos con `scp`. No se transfiere a EC2 ni se necesita para ejecutar `deploy.sh` dentro de la instancia. Las variables SSH deben mantenerse protegidas/enmascaradas en GitLab según corresponda. No ejecutar ambos modos contra el mismo host ni en paralelo si comparten destino.

---

## 11. Imágenes Docker en GitLab Container Registry

Las imágenes de la Parte 2 se publican en el Container Registry de GitLab del proyecto. Cada imagen utiliza el nombre del proyecto y se etiqueta con el commit que originó la construcción. También se publica `latest` para las pruebas, pero el despliegue debe preferir el tag específico del commit.

Por este motivo las imágenes no deben contener:

- archivos `.env`;
- claves privadas;
- tokens;
- contraseñas;
- certificados privados que no deban distribuirse.

Los valores sensibles necesarios en tiempo de ejecución se proporcionan externamente.

La autenticación del pipeline utiliza las variables automáticas `CI_REGISTRY_USER` y `CI_REGISTRY_PASSWORD`. Para descargar imágenes desde EC2 u otro equipo se utiliza un Deploy Token con permiso `read_registry`. Las credenciales no se escriben en el repositorio ni en las imágenes.

---

## 12. Archivos excluidos de Git

Los archivos sensibles o específicos del entorno deben permanecer fuera del repositorio.

Entre ellos:

```text
.env
*.pem
certs/*.key
secrets/dashboard_users
```

Antes de realizar un commit o push se debe comprobar:

```sh
git status
```

para evitar publicar accidentalmente información sensible.

---

## 13. Automatización del despliegue

GitLab ofrece dos jobs manuales con funciones distintas. `deploy_aws` conecta por SSH a una EC2 ya existente usando `AWS_EC2_HOST`, `AWS_EC2_USER` y `AWS_SSH_PRIVATE_KEY`; `deploy_terraform` aprovisiona/despliega en una EC2 separada con credenciales AWS temporales y una clave efímera. Ambos transfieren las ocho imágenes desde el runner —la instancia no recibe credenciales del Registry—, generan `.env`, certificado y hash de dashboard en el runner, y los copian a EC2 como archivos runtime necesarios. Los temporales del runner se eliminan mediante trap; los secretos runtime de EC2 no se borran porque los necesita el servicio.

Terraform utiliza el state remoto fijo `fintech-nova-sandbox`. Un apply posterior puede reemplazar la instancia debido al cambio de sufijo/key pair. Como el root EBS tiene `delete_on_termination`, se pierde el disco y la base de datos local; se deben respaldar los datos antes de aplicar de nuevo. El pipeline no tiene `destroy_ec2`; el Sandbox de AWS Academy puede expirar o resetear los recursos. `terraform init` dentro del job valida el backend, sin un job state-probe separado.

---

## 14. Seguridad integrada en GitLab CI/CD

El pipeline ejecuta los controles en el stage `security`, después de construir y publicar las imágenes y antes del stage `deploy`:

| Control | Herramienta | Alcance | Resultado |
|---|---|---|---|
| `analizar_codigo_semgrep` | Semgrep | Código fuente, Dockerfiles, YAML y lenguajes de las APIs | Bloquea hallazgos `ERROR` y genera `semgrep-report.json`. |
| `analizar_imagenes_trivy` | Trivy | Las ocho imágenes del commit | Analiza vulnerabilidades corregibles `HIGH` y `CRITICAL` y genera un JSON por imagen; con `allow_failure: true`, un hallazgo no bloquea el pipeline. |
| `analizar_dockerfiles` | Hadolint | Los ocho Dockerfiles declarados explícitamente | Bloquea errores de buenas prácticas Docker. |
| `analizar_archivos_yaml` | Yamllint | CI, Compose y configuración de Traefik | Bloquea errores de sintaxis y formato YAML. |
| `detectar_secretos` | Gitleaks | Árbol del repositorio | Bloquea secretos detectados y genera un reporte. |

Los reportes de Semgrep, Trivy, Hadolint, Yamllint y Gitleaks se conservan como artifacts del pipeline durante una semana. El despliegue no debe ejecutarse si un control bloqueante falla.

Se retiraron `probar_docker` y `probar_descarga_imagen` porque eran pruebas auxiliares del runner y del registry, no controles de seguridad del producto. La descarga de imágenes ocurre en los jobs de build/deploy; el escaneo Trivy de imágenes no constituye una validación de autorización SSH ni de acceso al Registry desde EC2.

El análisis detallado de los hallazgos está en [ANALISIS.md](ANALISIS.md). Los reportes JSON y de texto no se versionan: se conservan como artifacts descargables de los jobs correspondientes.

### Política ante vulnerabilidades

Los hallazgos `ERROR` de Semgrep y los errores bloqueantes de los demás controles detienen el pipeline. Trivy analiza vulnerabilidades `HIGH` y `CRITICAL` (ignorando las que no tienen corrección), pero al tener `allow_failure: true` es informativo y su fallo no impide continuar hacia el deploy manual. Sus reportes deben revisarse y los riesgos aceptados documentarse con impacto, justificación, medida compensatoria y responsable. No se afirma que Trivy sea actualmente un gate.

Los secretos se gestionan mediante variables protegidas y enmascaradas de GitLab o mediante archivos privados suministrados durante el despliegue. Nunca se agregan tokens, contraseñas, claves PEM, claves TLS ni archivos `.env` al repositorio.

## 15. Resumen

La arquitectura aplica las siguientes medidas:

- acceso público mediante HTTPS;
- terminación TLS centralizada en Traefik;
- puerto HTTP 80 cerrado;
- MariaDB sin exposición pública;
- APIs sin exposición directa;
- red interna Docker;
- variables sensibles fuera del código;
- `.env` no versionado;
- token de IPAPI mediante variable de entorno;
- dashboard de Traefik protegido mediante BasicAuth;
- acceso SSH mediante clave privada;
- SSH restringido por Security Group;
- imágenes Docker sin credenciales;
- archivos sensibles excluidos del repositorio.
- análisis SAST, vulnerabilidades de imágenes, Dockerfiles, YAML y secretos integrados al pipeline.

## Actualización CI/CD y Terraform (noviembre 2026)

El nuevo `test_api_clientes` usa una base de datos simulada y no necesita secretos. `validar_terraform` verifica formato y configuración, pero no reemplaza una revisión de permisos IAM, Security Groups ni el análisis de riesgos. Trivy continúa con `allow_failure: true`: las vulnerabilidades HIGH/CRITICAL pueden producir advertencias sin bloquear el despliegue. Las credenciales temporales de AWS y del backend HTTP de Terraform se suministran mediante variables de GitLab, nunca deben subirse al repositorio. El runner transfiere las imágenes a EC2 mediante SSH y `docker load`; la EC2 no hace login directo al registry. Revisar el informe de Trivy antes de aceptar riesgos.


## Corrección de vulnerabilidades detectadas en el TP — noviembre 2026

En los análisis previos de Trivy se identificaron **cuatro hallazgos HIGH** asociados a `CVE-2026-109518`: dos en la imagen de MariaDB (paquetes `apt` y `libapt-pkg6.0t64`) y dos en la imagen de API Facturas (`apt` y `libapt-pkg6.0`).

Se actualizaron los Dockerfiles para ejecutar `apt-get update` y `apt-get install --only-upgrade` de los paquetes afectados durante la construcción de las imágenes, sin cambiar las versiones principales de MariaDB y Java. Los cambios se subieron en el commit `19b4346`.

En el pipeline **#16409**, los jobs `build_db`, `build_facturas` y `analizar_imagenes_trivy` aparecieron en verde y el pipeline finalizó aprobado. Esto demuestra que el análisis configurado no detectó un hallazgo que hiciera fallar ese job en esa ejecución; **no equivale a una garantía de ausencia de todas las vulnerabilidades**. Para auditar los paquetes y CVE exactos, consultar los artifacts JSON de Trivy de ese pipeline.

En el log de pruebas de Tarjetas también se observó una advertencia `NU1902` sobre `MySqlConnector 2.3.7` (severidad moderada). No fue la causa del fallo del smoke test; queda como **mejora pendiente de evaluación**, revisando una versión corregida compatible y volviendo a ejecutar las pruebas. La configuración actual de Trivy se centra en `HIGH` y `CRITICAL`, por lo que no se debe afirmar que cubre todos los avisos moderados.

Para el alcance de las pruebas automatizadas y la explicación del pipeline, consultar [README_PARTE_2.md](README_PARTE_2.md).
