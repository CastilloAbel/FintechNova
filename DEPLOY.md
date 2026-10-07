# Build y despliegue en EC2

El flujo queda separado en dos partes: `build.sh` construye y publica las imágenes desde la PC; `deploy.sh` se copia a EC2 y se ejecuta allí. La clave privada PEM nunca se copia a la instancia.

## 1. Publicar las imágenes desde la PC

Inicia sesión en Docker Hub y publica las ocho imágenes:

```sh
docker login
./build.sh <DOCKER_USER> <IMAGE_TAG>
```

Por ejemplo, usa el mismo namespace y tag que después quedarán en el archivo `.env`. `build.sh` no se modifica y no realiza despliegues.

## 2. Preparar `.env`

Completa el `.env` local con los valores de la aplicación y verifica que incluya:

```dotenv
DOCKER_USER=tu_usuario_de_dockerhub
IMAGE_TAG=1.0.0
```

Deben coincidir con los argumentos usados en `build.sh`. El archivo `.env` contiene credenciales; no lo subas a Git. El archivo `env.example` sirve de plantilla.

## 3. Crear y configurar la instancia

Crea una instancia Amazon Linux 2023. El script acepta arquitecturas `x86_64` y `aarch64`. En el Security Group permite:

- TCP 22 desde tu IP pública autorizada;
- TCP 443 desde los clientes que deban acceder a la aplicación;
- salida a Internet para instalar paquetes y descargar las imágenes.

No hace falta abrir los puertos de las APIs ni de MariaDB. Conserva el `.pem` únicamente en la PC y usa el usuario `ec2-user` para Amazon Linux.

## 4. Copiar los archivos desde la PC

Desde la raíz de `tp-1`, copia únicamente lo necesario para ejecutar Compose:

Si el despliegue anterior se ejecutó desde `/home/ec2-user` con el script viejo, detén ese proyecto una vez antes de cambiar la ubicación. Este comando explícito apunta a los contenedores existentes y conserva el volumen (no uses `-v`):

```sh
ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> \
  'cd /home/ec2-user && sudo docker compose --project-name tp-1 --env-file .env -f docker-compose.yml down'
```

La opción `--project-name` se necesita aquí solo para retirar el despliegue anterior, que se creó con ese nombre desde otra carpeta. Los siguientes despliegues y comandos usarán la carpeta `~/tp-1` y no la necesitarán.

```sh
ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> "mkdir -p /home/ec2-user/tp-1"
scp -i "FinTech-Nova.pem" -r certs/ secrets/ .env docker-compose.yml deploy.sh ec2-user@<DNS_O_IP_PUBLICA>:/home/ec2-user/tp-1/
```

Sustituye `<DNS_O_IP_PUBLICA>` por la dirección actual de la instancia. No agregues la clave PEM a la lista de archivos.

## 5. Ejecutar el despliegue en EC2

```sh
ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> "bash ~/tp-1/deploy.sh"
```

La carpeta remota debe llamarse `tp-1`: Compose la usa para deducir el nombre del proyecto. El script no pasa `--project-name`. Así, Compose utiliza el mismo proyecto y volumen cuando se ejecuta manualmente desde `~/tp-1`.

El script, ya dentro de EC2:

1. comprueba los archivos requeridos y restringe permisos de `.env`, la clave TLS y el secreto del dashboard;
2. instala Docker, comprueba que esté disponible `curl` (normalmente `curl-minimal` en Amazon Linux 2023), habilita Docker al inicio y prepara el plugin oficial de Docker Compose;
3. valida la configuración y que estén definidas las ocho imágenes;
4. descarga las imágenes con `docker compose pull` y levanta los servicios con `docker compose up -d`;
5. muestra `docker compose ps` y exige que los ocho contenedores estén en ejecución;
6. prueba por HTTPS que la web y las cinco APIs respondan HTTP 200, y que `/dashboard/` responda HTTP 401 sin autenticación.

Las pruebas HTTP se hacen desde la propia instancia contra `127.0.0.1`; el certificado es autofirmado, por eso `curl` usa `-k`. Se verifica el código de respuesta HTTP, no se analiza el cuerpo JSON ni se valida la lógica funcional interna de cada API. Las rutas actuales de Traefik se seleccionan por path. El script no compila imágenes, no necesita la clave PEM y no ejecuta `docker compose down` ni elimina volúmenes. Usa `sudo docker` en vez de agregar `ec2-user` al grupo `docker`, que concede privilegios equivalentes a root.

## 6. Comprobaciones posteriores

Para revisar el estado o los logs más tarde:

```sh
ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> \
  'cd ~/tp-1 && sudo docker compose --env-file .env ps'

ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> \
  'cd ~/tp-1 && sudo docker compose --env-file .env logs'
```

Para detener o recrear los servicios sin borrar los datos, ejecuta `sudo docker compose down` desde `~/tp-1` y luego `sudo docker compose up -d` desde esa misma carpeta. No agregues `-v` si quieres conservar la base.

Si un servicio falla, revisa primero `docker compose ps` y sus logs. Comprueba también que `DOCKER_USER`/`IMAGE_TAG` correspondan a imágenes publicadas, que `.env` tenga las credenciales correctas y que el Security Group permita TCP 443.

