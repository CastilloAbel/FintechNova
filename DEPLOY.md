# Build y despliegue en EC2

## Despliegue automático al integrar cambios

El pipeline conserva un único job de despliegue: `deploy_terraform`. `deploy_aws`, que desplegaba por SSH en una EC2 preexistente, fue retirado del CI. Los scripts históricos siguen en el repositorio para referencia y uso fuera de este job.

`deploy_terraform` se ejecuta automáticamente, sin botón manual, únicamente en pipelines de tipo `push` de la rama `main` y después de que test, build y security finalicen correctamente. Al integrar a `main` una rama con prefijo `feat/` (por ejemplo, `feat/nueva-api`), el push resultante inicia el pipeline de `main` y, si pasa los controles, aprovisiona/actualiza EC2 y despliega. En ramas `feat/*` el pipeline valida, construye y analiza, pero no despliega.

La regla CI ve que el pipeline corresponde a un push de `main`; GitLab no expone en ese pipeline normal el nombre de la rama fuente que se mergeó. Por tanto, cualquier otro cambio que llegue a `main` también desplegaría. Para que la política del repositorio sea exclusivamente “merge desde `feat/*`”, proteger `main`, deshabilitar pushes directos y aceptar cambios únicamente mediante merge requests desde ramas con ese prefijo.

Antes de mergear, iniciar AWS Academy Learner Lab y actualizar las variables temporales protegidas. Si las credenciales no están disponibles en `main`, el deploy fallará y el pipeline quedará fallido; el job Terraform no permite el fallo. Cuando `deploy.sh` y sus verificaciones HTTPS concluyen correctamente, el log imprime `https://<IP>/` y la URL del dashboard. El certificado es autofirmado.

El job invoca `scripts/deploy-ci.sh` para preparar EC2, transferir las imágenes y archivos runtime y ejecutar las verificaciones. Las imágenes del commit se descargan en el runner y se cargan en EC2 porque `deploy.sh` usa `--pull never`. El `terraform init` del job valida el backend HTTP; no se ejecuta un `terraform_state_probe` separado.

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

Las variables Protected solo están disponibles en ramas protegidas. Proteger `main` y confirmar que las variables necesarias tengan alcance para esta rama. Nunca pegar credenciales AWS o claves privadas en el YAML, el state o artifacts.

### Ejecutar y persistencia del state

1. Iniciar el Learner Lab y refrescar las credenciales/variables protegidas antes de integrar cambios a `main`.
2. Abrir un merge request desde `feat/*` y, una vez aprobado, mergearlo a `main`. El pipeline de `main` lanzará automáticamente `deploy_terraform` tras los controles previos. Terraform genera una clave Ed25519 efímera, envía solo la pública a AWS y aprovisiona/actualiza la instancia. La clave privada, el plan, la configuración Docker y otros archivos temporales se eliminan del runner incluso ante fallo.
3. El state HTTP permanece fijo en `fintech-nova-sandbox`; no se crea un state por pipeline ni se acumulan instancias independientes administradas por el mismo flujo. Como el sufijo/key pair cambia por pipeline, un apply sucesivo puede reemplazar la instancia del state. El root EBS tiene `delete_on_termination`; al reemplazarla se pierde el disco y la base de datos local. Con el deploy automático, este reemplazo puede ocurrir en cada merge a `main`: no conservar allí datos que deban persistir. Respaldar cualquier dato necesario antes de integrar cambios que vuelvan a aplicar Terraform.
4. No existe un job CI `destroy_ec2`: el pipeline no ofrece una acción para terminar la instancia. AWS Academy puede expirar o resetear los recursos al finalizar la sesión; revisar el estado y las reglas del Sandbox.

Si aún existe en GitLab el state de prueba antiguo `fintech-state-probe`, eliminarlo manualmente desde la interfaz de Terraform States solo después de confirmar que es el state desechable del probe. No se usa ni se modifica desde el pipeline.

El job recorta espacios y normaliza una IP IPv4 simple como `/32`; también acepta la forma explícita `/32`. Rechaza redes más amplias, IPv6 y valores malformados. El SG abre únicamente SSH desde esa dirección y HTTPS `443` desde Internet; HTTP, APIs y DB no se publican. `resource_group: aws-sandbox` serializa los applies Terraform. La EC2 y el disco consumen cuotas/presupuesto del Lab; “Free tier eligible” no garantiza costo cero en AWS Academy.

## Procedimiento manual histórico (referencia)

La sección siguiente describe el procedimiento histórico ejecutado desde una PC, que usaba Docker Hub y una PEM local. Se conserva como referencia junto con los scripts operativos ubicados en `scripts/`; no es el flujo CI actual, que usa Terraform y GitLab Container Registry. La clave privada efímera de Terraform nunca se copia a EC2.

El flujo manual usa tres scripts ubicados en `scripts/`: `build.sh` construye y publica las imágenes desde la PC; `prepare-deploy.sh` crea localmente el certificado y el usuario del dashboard; `deploy.sh` se copia a EC2 con su nombre original y se ejecuta allí.

## 1. Publicar las imágenes desde la PC

Inicia sesión en Docker Hub y publica las ocho imágenes:

```sh
docker login
bash scripts/build.sh <DOCKER_USER> <IMAGE_TAG>
```

Por ejemplo, usa el mismo namespace y tag que después quedarán en el archivo `.env`. `scripts/build.sh` no realiza despliegues.

## 2. Preparar `.env`

Completa el `.env` local con los valores de la aplicación y verifica que incluya:

```dotenv
DOCKER_USER=tu_usuario_de_dockerhub
IMAGE_TAG=1.0.0
```

Deben coincidir con los argumentos usados en `scripts/build.sh`. El archivo `.env` contiene credenciales; no lo subas a Git. El archivo `env.example` sirve de plantilla.

## 3. Generar certificado y usuario del dashboard

Antes de copiar archivos a EC2, desde la raíz del repositorio ejecuta `scripts/prepare-deploy.sh` indicando el nombre de usuario que quieras crear:

```sh
bash scripts/prepare-deploy.sh abel
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
scp -i "FinTech-Nova.pem" -r certs/ secrets/ .env docker-compose.yml scripts/deploy.sh ec2-user@<DNS_O_IP_PUBLICA>:/home/ec2-user/tp-1/
```

Sustituye `<DNS_O_IP_PUBLICA>` por la dirección actual de la instancia. No agregues la clave PEM a la lista de archivos.

## 6. Ejecutar el despliegue en EC2

```sh
ssh -i "FinTech-Nova.pem" ec2-user@<DNS_O_IP_PUBLICA> "bash ~/tp-1/deploy.sh"
```

La carpeta remota debe llamarse `tp-1`: Compose la usa para deducir el nombre del proyecto. El script no pasa `--project-name`. Así, Compose utiliza el mismo proyecto y volumen cuando se ejecuta manualmente desde `~/tp-1`.

El script remoto `deploy.sh`, ya dentro de EC2:

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

