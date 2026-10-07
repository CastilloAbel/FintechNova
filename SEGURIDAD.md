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

El acceso administrativo a EC2 se realiza utilizando una clave privada `.pem`.

La clave privada:

- no se almacena en Git;
- no se incluye en las imágenes Docker;
- no se copia dentro del proyecto;
- debe conservar permisos restringidos.

Durante las pruebas desde WSL fue necesario almacenar una copia de la clave en el directorio personal y asignarle:

```sh
chmod 600 ~/FinTech-Nova.pem
```

La ruta de la clave se proporciona al proceso de despliegue mediante:

```sh
export SSH_KEY="$HOME/FinTech-Nova.pem"
```

---

## 11. Imágenes Docker públicas

Las imágenes del Trabajo Práctico se publican en Docker Hub para permitir que la instancia EC2 pueda descargarlas durante el despliegue.

Por este motivo las imágenes no deben contener:

- archivos `.env`;
- claves privadas;
- tokens;
- contraseñas;
- certificados privados que no deban distribuirse.

Los valores sensibles necesarios en tiempo de ejecución se proporcionan externamente.

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

`deploy.sh` necesita información privada para acceder a EC2 y configurar el entorno.

Estos valores no se encuentran hardcodeados en el script.

Por ejemplo:

```sh
export EC2_HOST=<IP_EC2>
export SSH_KEY=<RUTA_CLAVE_PEM>

bash deploy.sh deploy <DOCKER_USER> <IMAGE_TAG>
```

Esto permite reutilizar el mismo script con diferentes instancias sin almacenar la clave privada dentro del repositorio.

---

## 14. Resumen

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