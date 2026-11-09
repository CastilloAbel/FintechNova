# Build y despliegue en EC2

## Despliegues manuales desde GitLab CI

El pipeline ofrece dos jobs manuales, con destinos y credenciales separados. Ambos esperan a que terminen correctamente las etapas anteriores de test, build y security. No se deben ejecutar contra el mismo host ni en paralelo si se configura accidentalmente el mismo destino.

| Job | Destino y función | Ramas |
|---|---|---|
| `deploy_aws` | Despliega en una EC2 ya existente usando `AWS_EC2_HOST`, `AWS_EC2_USER` y `AWS_SSH_PRIVATE_KEY`. Descarga las ocho imágenes del Container Registry en el runner y las transfiere por SSH. | `main`, `feature/deploy-aws`, `feature/test-deploy-ec2` |
| `deploy_terraform` | Usa Terraform para aprovisionar/actualizar otra EC2 y después instala Docker, transfiere imágenes y despliega. No utiliza las credenciales SSH de `deploy_aws`. | `main`, `deploy/terraform` |

Tras ejecutar `deploy.sh` y sus verificaciones HTTPS, cada job imprime `https://<IP>/` y la URL del dashboard. El certificado es autofirmado.

### Ruta legacy: `deploy_aws`

Configura en GitLab las variables `AWS_EC2_HOST` (IPv4 pública), `AWS_EC2_USER` y `AWS_SSH_PRIVATE_KEY` (variable de tipo archivo), además de `DB_USER`, `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `DASHBOARD_USER`, `DASHBOARD_PASSWORD` y, si aplica, `IPAPI_TOKEN`. Protege y enmascara los valores sensibles. La EC2 debe estar activa, aceptar SSH desde el runner y ser Amazon Linux compatible con `setup-ec2.sh`.

El runner inicia sesión en el Container Registry, descarga las imágenes etiquetadas con el commit y las carga en la instancia. Es necesario porque `deploy.sh` inicia Compose con `--pull never`; la EC2 no hace pull por sí misma. Este job no aprovisiona ni destruye la instancia.

### Ruta Terraform: `deploy_terraform`

En `main` o `deploy/terraform`, ejecutar manualmente `deploy_terraform`. Antes hay que iniciar AWS Academy Learner Lab y actualizar sus credenciales. `terraform init` valida el backend HTTP durante el propio deploy; ya no hay un job `terraform_state_probe` en el flujo.

### Variables requeridas por sesión

Después de iniciar el Sandbox, actualizar en **Settings → CI/CD → Variables**:

| Variable | Uso | Protección |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Access key temporal del Lab | Masked y Protected |
| `AWS_SECRET_ACCESS_KEY` | Secret key temporal del Lab | Masked y Protected |
| `AWS_SESSION_TOKEN` | Token temporal requerido por Academy | Masked y Protected |
| `AWS_DEFAULT_REGION` | Región actual del Lab donde existe la AMI | Protected; no es secreto |
| `RUNNER_EGRESS_CIDR` | IP IPv4 de salida actual del runner, por ejemplo `200.10.191.20` o `200.10.191.20/32` | Protected; confirmar el egress antes de cada sesión |
| `TF_STATE_USERNAME` | Usuario del token de acceso al Terraform State de GitLab | Protected |
| `TF_STATE_PASSWORD` | Token usado por el backend HTTP de Terraform State | Masked y Protected |
| `DB_USER`, `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD` | Credenciales de MariaDB | Masked y Protected |
| `DASHBOARD_USER`, `DASHBOARD_PASSWORD` | Autenticación BasicAuth del dashboard | Password Masked y Protected |
| `IPAPI_TOKEN` | Token de la integración externa de Transacciones, si se utiliza | Masked y Protected |

La AMI predeterminada `ami-0c230065b91270bc6` es un identificador regional. Confirmar que corresponde a Amazon Linux 2023 x86_64 en `AWS_DEFAULT_REGION`; si no, sobrescribir el valor no secreto `AWS_EC2_AMI_ID` en variables CI/CD. La instancia se configura como `t3.small` con root volume gp3 de 20 GiB.

Las variables Protected solo están disponibles en ramas protegidas. Proteger `deploy/terraform` mientras se valida esta implementación o ejecutar desde `main` después de integrar el cambio. Nunca pegar credenciales AWS o claves privadas en el YAML, el state o artifacts.

### Ejecutar y persistencia del state

1. Iniciar el Learner Lab y refrescar las credenciales/variables de esa sesión.
2. Lanzar manualmente `deploy_terraform`. Terraform genera una clave Ed25519 efímera, envía solo la pública a AWS, aprovisiona/actualiza la instancia y ejecuta el despliegue. La clave privada, el plan, la configuración Docker y otros archivos temporales se eliminan del runner incluso ante fallo.
3. El state HTTP permanece fijo en `fintech-nova-sandbox`; no se crea un state por pipeline y no se acumulan instancias independientes administradas por el mismo flujo. Como el sufijo/key pair cambia por pipeline, un apply sucesivo puede reemplazar la instancia del state. El root EBS tiene `delete_on_termination`; al reemplazarla se pierde el disco y la base de datos local. Respaldar cualquier dato necesario antes de otro apply.
4. No existe un job CI `destroy_ec2`: el pipeline no ofrece una acción para terminar la instancia. AWS Academy puede expirar o resetear los recursos al finalizar la sesión; revisar el estado y las reglas del Sandbox.

Si aún existe en GitLab el state de prueba antiguo `fintech-state-probe`, eliminarlo manualmente desde la interfaz de Terraform States solo después de confirmar que es el state desechable del probe. No se usa ni se modifica desde el pipeline.

El job recorta espacios y normaliza una IP IPv4 simple como `/32`; también acepta la forma explícita `/32`. Rechaza redes más amplias, IPv6 y valores malformados. El SG abre únicamente SSH desde esa dirección y HTTPS `443` desde Internet; HTTP, APIs y DB no se publican. `resource_group: aws-sandbox` serializa los applies Terraform. La EC2 y el disco consumen cuotas/presupuesto del Lab; “Free tier eligible” no garantiza costo cero en AWS Academy.

## Procedimiento manual histórico (referencia)

La sección siguiente describe el procedimiento histórico ejecutado desde una PC, que usaba Docker Hub y una PEM local. Se conserva como referencia junto con `build.sh`, `prepare-deploy.sh`, `setup-ec2.sh` y `deploy.sh`; no es el job CI `deploy_aws` restaurado, que usa Container Registry y una EC2 existente. La clave privada efímera de Terraform nunca se copia a EC2.

El flujo manual usa tres scripts: `build.sh` construye y publica las imágenes desde la PC; `prepare-deploy.sh` crea localmente el certificado y el usuario del dashboard; `deploy.sh` se copia a EC2 y se ejecuta allí.

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

## 3. Generar certificado y usuario del dashboard

Antes de copiar archivos a EC2, desde la raíz del repositorio ejecuta el script local `prepare-deploy.sh` indicando el nombre de usuario que quieras crear:

```sh
bash prepare-deploy.sh abel
```

El script solicita la contraseña dos veces sin mostrarla ni recibirla como argumento. La envía por entrada estándar al contenedor `httpd:2.4` para generar el hash compatible con Traefik y agrega `usuario:hash` al final de `secrets/dashboard_users`. Docker descargará esa imagen si no está localmente.

También genera `certs/local.crt` y `certs/local.key` con el CN fijo `*.19.grupo.devops.frc.utn.edu.ar` y vigencia de 365 días. En cada ejecución reemplaza el certificado y la clave anteriores. Los usuarios nuevos se agregan al archivo de secretos; si el nombre ya existe, el script se detiene para evitar entradas duplicadas. No edites ni compartas la contraseña o el hash.

Requisitos en la PC: Docker iniciado y OpenSSL disponible. Las carpetas `certs/` y `secrets/` deben existir; el script no las crea. Estos archivos están excluidos de Git.

## 4. Crear y configurar la instancia

Crea una instancia Amazon Linux 2023. El script acepta arquitecturas `x86_64` y `aarch64`. En el Security Group permite:

- TCP 22 desde tu IP pública autorizada;
- TCP 443 desde los clientes que deban acceder a la aplicación;
- salida a Internet para instalar paquetes y descargar las imágenes.

No hace falta abrir los puertos de las APIs ni de MariaDB. Conserva el `.pem` únicamente en la PC y usa el usuario `ec2-user` para Amazon Linux.

## 5. Copiar los archivos desde la PC

Desde la raíz de `tp-1`, copia únicamente lo necesario para ejecutar Compose:

Si el despliegue anterior se ejecutó desde `/home/ec2-user` con el script viejo, detén ese proyecto una vez antes de cambiar la ubicación. Este comando explícito apunta a los contenedores existentes y conserva el volumen (no uses `-v`):

```sh
ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> \
  'cd /home/ec2-user/tp-1 && sudo docker compose -f docker-compose.yml down'
```


```sh
scp -i "FinTech-Nova.pem" -r certs/ secrets/ .env docker-compose.yml deploy.sh ec2-user@<DNS_O_IP_PUBLICA>:/home/ec2-user/tp-1/
```

Sustituye `<DNS_O_IP_PUBLICA>` por la dirección actual de la instancia. No agregues la clave PEM a la lista de archivos.

## 6. Ejecutar el despliegue en EC2

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

## 7. Comprobaciones posteriores

Para revisar el estado o los logs más tarde:

```sh
ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> \
  'cd ~/tp-1 && sudo docker compose --env-file .env ps'

ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> \
  'cd ~/tp-1 && sudo docker compose --env-file .env logs'
```

Para detener o recrear los servicios sin borrar los datos, ejecuta `sudo docker compose down` desde `~/tp-1` y luego `sudo docker compose up -d` desde esa misma carpeta. No agregues `-v` si quieres conservar la base.

Si un servicio falla, revisa primero `docker compose ps` y sus logs. Comprueba también que `DOCKER_USER`/`IMAGE_TAG` correspondan a imágenes publicadas, que `.env` tenga las credenciales correctas y que el Security Group permita TCP 443.

