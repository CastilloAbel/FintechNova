# Build y despliegue

La automatización del TP se divide en dos scripts:

- `build.sh`: construye y publica las 8 imágenes en Docker Hub.
- `deploy.sh`: valida la configuración, despliega en EC2 y verifica los endpoints HTTPS.

Los scripts se ejecutan desde la PC local utilizando Bash (WSL, Git Bash o Linux).

---

## 1. build.sh

Construye las 8 imágenes del proyecto y las publica en Docker Hub.

Antes de ejecutarlo es necesario:

- Tener Docker iniciado.
- Haber iniciado sesión previamente con `docker login`.

El script recibe dos parámetros:

1. Namespace de Docker Hub.
2. Tag que se utilizará para todas las imágenes.

Ejemplo:

```bash
./build.sh camilagea 1.0.0
```

También puede ejecutarse con:

```bash
bash build.sh camilagea 1.0.0
```

El script construye:

- tp1-traefik
- tp1-db
- tp1-api-clientes
- tp1-api-pagos
- tp1-api-facturas
- tp1-api-tarjetas
- tp1-api-transacciones
- tp1-web

En el ejemplo anterior se publicarán como:

```text
camilagea/tp1-traefik:1.0.0
camilagea/tp1-db:1.0.0
camilagea/tp1-api-clientes:1.0.0
camilagea/tp1-api-pagos:1.0.0
camilagea/tp1-api-facturas:1.0.0
camilagea/tp1-api-tarjetas:1.0.0
camilagea/tp1-api-transacciones:1.0.0
camilagea/tp1-web:1.0.0
```

Primero se construyen las 8 imágenes.

Solamente si las 8 construcciones terminan correctamente comienza la publicación en Docker Hub.

`build.sh` no realiza ningún despliegue en AWS.

---

## 2. deploy.sh

`deploy.sh` utiliza las imágenes publicadas para validar o desplegar el proyecto.

Su formato es:

```bash
bash deploy.sh [check|deploy|verify] namespace tag
```

Por ejemplo:

```bash
bash deploy.sh check camilagea 1.0.0
```

El namespace y el tag deben coincidir con los utilizados previamente en `build.sh`.

### Modo check

Valida localmente la configuración del proyecto.

```bash
bash deploy.sh check camilagea 1.0.0
```

Comprueba el Docker Compose y la configuración necesaria de los servicios.

No se conecta a AWS, no construye imágenes y no publica imágenes.

### Modo deploy

Realiza el despliegue en una instancia EC2.

Antes de ejecutarlo se deben definir la dirección actual de la instancia y la clave SSH.

Ejemplo:

```bash
export EC2_HOST=IP_O_DNS_ACTUAL
export SSH_KEY=/ruta/a/fintech-nova-key.pem
```

Luego:

```bash
bash deploy.sh deploy camilagea 1.0.0
```

El modo `deploy`:

1. Se conecta a la EC2 por SSH.
2. Prepara Docker y Docker Compose en Amazon Linux 2023.
3. Copia el `docker-compose.yml`, `.env`, certificados y secreto del dashboard.
4. Ejecuta `docker compose pull`.
5. Ejecuta `docker compose up -d`.
6. Ejecuta `docker compose ps`.
7. Verifica los endpoints HTTPS desde la PC local.

No elimina volúmenes ni utiliza `docker compose down -v`.

### Modo verify

Permite repetir solamente las pruebas HTTPS sobre un despliegue existente.

```bash
bash deploy.sh verify camilagea 1.0.0
```

No vuelve a construir ni desplegar los contenedores.

---

## 3. Imágenes utilizadas por Docker Compose

`docker-compose.yml` utiliza las variables:

```yaml
${DOCKER_USER}
${IMAGE_TAG}
```

Por ejemplo:

```yaml
image: ${DOCKER_USER}/tp1-api-clientes:${IMAGE_TAG}
```

Al ejecutar:

```bash
bash deploy.sh deploy camilagea 1.0.0
```

Compose utilizará:

```text
camilagea/tp1-api-clientes:1.0.0
```

Esto permite utilizar la misma configuración con otro namespace o una nueva versión sin modificar manualmente el Compose.

---

## 4. Archivos privados necesarios para AWS

Para el despliegue deben estar disponibles localmente:

```text
.env
certs/local.crt
certs/local.key
secrets/dashboard_users
```

También se necesita la clave `.pem` de la instancia EC2.

Estos archivos privados no deben publicarse en el repositorio.

La instancia debe permitir:

- SSH por puerto 22 desde la IP autorizada.
- HTTPS por puerto 443.
- Salida a Internet.

El puerto 80 no es necesario.

---

## 5. Verificaciones HTTPS

Después del despliegue se verifican:

```text
/
 /api/clientes
 /api/pagos
 /api/facturas
 /api/transacciones
 /api/tarjetas
```

La Web debe responder correctamente por HTTPS y las cinco APIs deben responder JSON.

También se verifica:

```text
/dashboard/
```

Sin credenciales debe responder HTTP 401, confirmando que el dashboard de Traefik requiere autenticación.

Las pruebas utilizan `curl -k` porque el proyecto utiliza un certificado autofirmado.

---

## Flujo completo

El flujo de automatización queda:

```bash
docker login

./build.sh camilagea 1.0.0

bash deploy.sh check camilagea 1.0.0

export EC2_HOST=IP_O_DNS_ACTUAL
export SSH_KEY=/ruta/a/fintech-nova-key.pem

bash deploy.sh deploy camilagea 1.0.0
```

Si posteriormente solo se quieren repetir las pruebas:

```bash
bash deploy.sh verify camilagea 1.0.0
```

De esta forma `build.sh` se encarga de construir y publicar, mientras que `deploy.sh` se encarga de validar, desplegar y verificar.