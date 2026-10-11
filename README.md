# FinTech Nova — Trabajo Práctico DevOps 2026

**Grupo 19 · Camila Gea (82327) · Abel Castillo (90322)**

FinTech Nova reúne la gestión de clientes, pagos, facturas, transacciones y tarjetas mediante una interfaz web y cinco APIs independientes. El trabajo comprende la dockerización de los componentes, su integración con Docker Compose y el despliegue en Amazon EC2 con acceso HTTPS.

La implementación incluye ocho imágenes publicadas en Docker Hub, una instancia compartida de MariaDB con almacenamiento persistente y tres scripts que separan la construcción, la preparación de archivos privados y el despliegue. Este documento presenta la arquitectura, las decisiones de implementación y las evidencias de las pruebas registradas.

## 1. Arquitectura e integración

<img src="docs/evidencias/diagrama-arquitectura.png" alt="Arquitectura de FinTech Nova" width="900">

La solución está compuesta por ocho contenedores. Cada API mantiene sus dependencias y su entorno de ejecución, lo que permite construir y actualizar los componentes de forma independiente.

| Servicio | Tecnología | Responsabilidad |
|---|---|---|
| `tp1-web` | JavaScript, Vite y `serve` | Interfaz para las cinco funcionalidades |
| `tp1-api-clientes` | Python / Flask | Gestión de clientes |
| `tp1-api-pagos` | Node.js / Express | Gestión de pagos y conversión ARS/USD |
| `tp1-api-facturas` | Java / Spring Boot | Gestión de facturas |
| `tp1-api-transacciones` | Go | Gestión de transacciones y geolocalización por IP |
| `tp1-api-tarjetas` | .NET / ASP.NET Core | Gestión de tarjetas |
| `tp1-db` | MariaDB | Almacenamiento de las cinco bases de las APIs |
| `traefik` | Traefik | Entrada HTTPS, enrutamiento y dashboard |

La web permite listar, agregar y borrar registros. Las APIs también implementan operaciones de actualización, aunque la interfaz actual no incluye un formulario de edición.

Todas las APIs acceden a una única instancia de MariaDB, con una base por funcionalidad. Pagos y Transacciones consultan además servicios externos para obtener el tipo de cambio y el país asociado a una dirección IP.

Las solicitudes del navegador llegan a Traefik, que las dirige a la web o a la API correspondiente. El acceso externo se concentra en el puerto HTTPS 443; las comunicaciones internas utilizan la red Docker `proxy`.

<img src="docs/evidencias/07-web-clientes.png" alt="Gestión de clientes" width="700">

*La web reúne las cinco funcionalidades en un mismo sitio. Las capturas corresponden a las pruebas documentadas.*

## 2. Dockerización y preparación de imágenes

Cada componente tiene un Dockerfile que define su imagen base, la instalación de dependencias, los archivos de la aplicación y el comando de inicio. Esta preparación queda registrada en el repositorio y se reproduce durante la construcción, sin instalar manualmente las dependencias de cada aplicación en EC2.

### Dependencias y construcción por etapas

Clientes instala las bibliotecas Python indicadas en `requirements.txt`. Pagos instala sus dependencias mediante `npm ci --omit=dev`. En ambos casos se copian primero los archivos de dependencias y después el código, permitiendo reutilizar la capa de instalación si solo cambia la aplicación.

Para los componentes que requieren compilación o generación de archivos se utilizan **multi-stage builds**. Una etapa contiene las herramientas de construcción y la etapa final recibe el resultado junto con el entorno necesario para ejecutarlo.

En Facturas, Maven compila el código Java y genera `api-facturas.jar`. Ese archivo se copia a una etapa con Java runtime. De esta manera, Maven y las herramientas de compilación quedan fuera de la imagen final. El mismo criterio se aplica a la publicación .NET, al ejecutable Go y a los archivos de la web generados por Vite.

Ambas etapas se realizan durante la construcción de la imagen. La aplicación se inicia posteriormente, al ejecutar el contenedor. En la web, la etapa final utiliza `serve` para publicar la carpeta `dist` en el puerto 8080; el Dockerfile actual no ejecuta Nginx.

En algunas aplicaciones se configura un usuario distinto de root para reducir los privilegios del proceso dentro del contenedor. Esta medida está implementada en Facturas, Tarjetas y Web.

### Configuración incorporada y arquitectura de destino

La imagen de MariaDB incorpora `init-scripts/` en `/docker-entrypoint-initdb.d/`. Estos archivos preparan las bases, permisos y tablas durante la primera inicialización. La imagen de Traefik incorpora `traefik.yml` y `dynamic/`, asociando las reglas de enrutamiento a la versión publicada.

Los contextos utilizados por `build.sh` coinciden con las rutas de copia de cada Dockerfile: Traefik utiliza su carpeta; MariaDB, Clientes y Pagos, sus respectivas carpetas; los otros componentes de aplicación utilizan `aplicaciones-contenedores`.

El build genera imágenes para `linux/amd64`, en correspondencia con la instancia x86_64 documentada. La compilación Go también fija esa arquitectura e incorpora certificados CA en la imagen final para consultar servicios externos mediante HTTPS.

**Implementación:** [Dockerfile de Facturas](aplicaciones-contenedores/api-facturas/Dockerfile), [Dockerfile de Web](aplicaciones-contenedores/web/Dockerfile), [Dockerfile de MariaDB](aplicaciones-contenedores/db/Dockerfile) y [Dockerfile de Traefik](traefik/Dockerfile).

## 3. Orquestación, configuración y persistencia

[docker-compose.yml](docker-compose.yml) define la ejecución de los ocho servicios mediante imágenes publicadas. No contiene una sección de construcción local: el entorno de EC2 descarga las imágenes y ejecuta sus contenedores.

### Selección de imágenes

Las referencias utilizan `DOCKER_USER` e `IMAGE_TAG` para seleccionar una cuenta de Docker Hub y una versión común:

```yaml
image: ${DOCKER_USER}/tp1-api-clientes:${IMAGE_TAG}
```

Esta estructura permite cambiar la publicación utilizada sin editar las ocho referencias individualmente. Los valores deben coincidir con los argumentos empleados al ejecutar `build.sh`.

### Red y variables de entorno

Los servicios se conectan a la red `proxy` y se encuentran por sus nombres. Las APIs acceden a MariaDB mediante `tp1-db:3306`, sin publicar el puerto 3306 al exterior. Compose publica únicamente `443:443` en Traefik.

La configuración se centraliza en un único archivo `.env`, en lugar de utilizar uno por microservicio. Compose toma sus valores y entrega a cada contenedor las variables declaradas en `environment`.

| Variables | Aplicación |
|---|---|
| `DOCKER_USER`, `IMAGE_TAG` | Cuenta y versión de las imágenes |
| `DB_HOST`, `DB_PORT` | Conexión interna a MariaDB |
| `DB_USER`, `DB_PASSWORD` | Usuario compartido de aplicación |
| `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE` | Inicialización de MariaDB |
| `DB_NAME_CLIENTES`, `DB_NAME_PAGOS`, `DB_NAME_FACTURAS`, `DB_NAME_TRANSACCIONES`, `DB_NAME_TARJETAS` | Base utilizada por cada API |
| `IPAPI_TOKEN` | Token entregado a Transacciones |

[env.example](env.example) documenta la configuración esperada sin credenciales privadas. Para una instalación nueva se copia como `.env` y se completan los valores; el archivo real se mantiene fuera de Git. La variable `DOMAIN` se entrega a Traefik, aunque las reglas actuales seleccionan solicitudes por ruta y no por dominio.

### Bases y almacenamiento persistente

MariaDB aloja `db_clientes`, `db_pagos`, `db_facturas`, `db_transacciones` y `db_tarjetas`. El script inicial crea las bases y concede permisos al mismo usuario de aplicación; los SQL numerados preparan las tablas. La separación es lógica: las bases comparten servidor, recursos y usuario.

El volumen `db_data` se monta en `/var/lib/mysql`. Al reemplazar el contenedor y reutilizar el mismo volumen, los datos permanecen disponibles. El despliegue habitual conserva ese volumen; `docker compose down -v` lo elimina junto con sus datos.

### Recursos y arranque

Traefik y MariaDB tienen límites de 0,50 CPU y 512 MB; cada API y la web tienen límites de 0,25 CPU y 256 MB. Estos valores acotan los recursos configurados en una instancia compartida y no representan mediciones de consumo.

Todos los servicios utilizan `restart: always`. Las APIs declaran `depends_on` para ordenar el arranque de MariaDB antes que ellas. Esta dependencia no verifica que la base ya esté disponible; los reintentos del despliegue contemplan el tiempo de inicialización.

## 4. Traefik, enrutamiento y HTTPS

Traefik centraliza la entrada HTTPS y dirige las solicitudes según su ruta. La configuración general establece `websecure` en `:443`; los archivos de `dynamic/` definen los routers, middlewares, servicios y certificado.

### Rutas y prioridades

| Ruta | Destino interno | Prioridad |
|---|---|---|
| `/api/clientes` | `http://tp1-api-clientes:8080` | 100 |
| `/api/pagos` | `http://tp1-api-pagos:8080` | 100 |
| `/api/facturas` | `http://tp1-api-facturas:8083` | 100 |
| `/api/transacciones` | `http://tp1-api-transacciones:8084` | 100 |
| `/api/tarjetas` | `http://tp1-api-tarjetas:8085` | 100 |
| `/dashboard` y `/api` del dashboard | `api@internal` | 10 |
| `/` | `http://tp1-web:8080` | 1 |

Las reglas específicas tienen prioridad sobre la ruta general de la web y sobre el prefijo del dashboard. Los middlewares `stripPrefix` eliminan `/api` antes de reenviar la solicitud.

Por ejemplo, la web envía `POST /api/clientes`; Traefik selecciona Clientes y reenvía `/clientes`. La API guarda el registro en `db_clientes`, devuelve la respuesta y la web vuelve a consultar el listado. Esta adaptación mantiene las rutas implementadas por las APIs y un prefijo público común.

Los destinos actuales se declaran en el proveedor de archivos. También se habilita el proveedor Docker con `exposedByDefault: false`. Cada servicio de negocio tiene un único destino configurado; no se implementan réplicas ni distribución entre varias instancias de una API.

### Certificado y terminación TLS

Traefik carga `certs/local.crt` y `certs/local.key`, montados durante el despliegue. El certificado contiene información de identidad y una clave pública; la clave privada correspondiente se mantiene secreta. TLS permite establecer la conexión cifrada entre navegador y proxy.

El certificado es autofirmado, con CN `*.19.grupo.devops.frc.utn.edu.ar`, RSA de 2048 bits y vigencia de 365 días. El navegador puede mostrar advertencias porque no confía automáticamente en su emisor y porque el nombre puede no coincidir con la IP utilizada.

TLS termina en Traefik. Los destinos internos utilizan HTTP dentro de Docker. El certificado y su clave se generan fuera de la imagen, evitando distribuir la clave privada en Docker Hub.

### Dashboard y archivos privados

El dashboard mantiene `insecure: false` y se protege con BasicAuth. Sus usuarios se leen de `/run/secrets/dashboard_users`, un archivo con hashes de contraseñas montado desde `secrets/`. Una solicitud sin credenciales debe recibir HTTP 401.

Esta autenticación corresponde al dashboard; no está aplicada a las rutas de negocio. Las carpetas de certificados y secretos se montan en modo de solo lectura. La configuración también monta el socket de Docker para su proveedor, lo que supone acceso sensible al motor del host.

**Implementación:** [traefik.yml](traefik/traefik.yml), [regla de Clientes](traefik/dynamic/clientes.yml), [dashboard](traefik/dynamic/dashboard.yml) y [TLS](traefik/dynamic/tls.yaml).

## 5. Automatización de construcción y publicación

[build.sh](build.sh) automatiza la construcción y carga de las ocho imágenes en Docker Hub. Se ejecuta en la PC con Docker iniciado y una sesión previa en el registro:

```bash
docker login
bash build.sh camilagea prueba-2026-10-11
```

La cuenta y el tag del ejemplo corresponden a la prueba documentada y se reemplazan para otra publicación. El script valida los argumentos, comprueba Docker y verifica la existencia de los Dockerfiles. Después construye todas las imágenes con `--pull` y `--platform linux/amd64`.

Solo cuando las ocho construcciones terminaron correctamente comienza la publicación. Un fallo de construcción detiene el proceso antes de subir imágenes; un fallo de envío puede dejar una publicación parcial.

![Imágenes en Docker Hub](docs/evidencias/03-docker-hub-imagenes.png)

Se publican `tp1-traefik`, `tp1-db`, las cinco `tp1-api-*` y `tp1-web`, bajo la misma cuenta y tag. EC2 descarga estas imágenes durante el despliegue. Los tags pueden reemplazarse si se vuelven a publicar; para distinguir entregas conviene utilizar una versión nueva.

## 6. Creación y configuración de EC2

La instancia y su Security Group se preparan antes de ejecutar el despliegue. La prueba desde cero realizada el 11 de octubre de 2026 utilizó el siguiente entorno:

| Configuración | Valor documentado |
|---|---|
| Nombre | `FinTech-Nova-Prueba` |
| Sistema operativo | Amazon Linux 2023 |
| Arquitectura | x86_64 |
| Tipo | `t3.medium` |
| Almacenamiento | 8 GiB gp3 |
| Usuario SSH | `ec2-user` |
| Región y zona | us-east-1 / us-east-1b |
| IP de la prueba registrada | `52.91.112.148` |
| ID de instancia | `i-07c2ae8065fbd7e3d` |
| Imágenes utilizadas | `camilagea/*:prueba-2026-10-11` |

![Instancia EC2](docs/evidencias/09-ec2-detalles.png)

Durante la creación se generó un par de claves y se descargó el archivo `Nombre_ FinTech-Nova-Prueba.pem`. El archivo privado permanece en la PC y se utiliza para autenticar las conexiones SSH y las transferencias SCP. Es distinto de la clave TLS de Traefik.

El Security Group permite SSH por TCP 22 desde la IP autorizada y HTTPS por TCP 443 desde `0.0.0.0/0`. No se habilita el puerto 80 ni los puertos internos de las APIs o MariaDB. La salida permite instalar paquetes, descargar imágenes y consultar las APIs externas.

![Security Group](docs/evidencias/10-ec2-security-group.png)

La IP registrada identifica la prueba documentada y no constituye una dirección garantizada para el entorno actual. `deploy.sh` no crea la instancia ni configura estas reglas.

## 7. Preparación, transferencia y despliegue

El flujo separa las responsabilidades de los tres scripts:

```text
PC: build.sh → ocho imágenes en Docker Hub
PC: prepare-deploy.sh → certificado, clave TLS y usuario del dashboard
PC: SCP → archivos de ejecución en EC2
EC2: deploy.sh → instalación, descarga, inicio y verificaciones
```

### Preparación de archivos privados

[prepare-deploy.sh](prepare-deploy.sh) se ejecuta en la PC con Docker iniciado y OpenSSL disponible:

```bash
bash prepare-deploy.sh camila
```

Solicita dos veces la contraseña sin mostrarla y utiliza `htpasswd` en un contenedor temporal para generar el hash. Agrega el usuario a `secrets/dashboard_users` y rechaza nombres duplicados.

También genera el certificado y la clave TLS. Cada ejecución reemplaza ese par; los usuarios nuevos se agregan al archivo. Las carpetas `certs/` y `secrets/` deben existir previamente. La clave privada y el archivo de usuarios quedan con permisos 600.

### Transferencia y ejecución remota

Se copian Compose, `.env`, certificados, usuarios y `deploy.sh`. El código fuente no necesita transferirse porque ya está en las imágenes; la PEM se utiliza desde la PC y no se copia a EC2.

```bash
ssh -i "RUTA_CLAVE.pem" ec2-user@IP_EC2 'mkdir -p ~/tp-1'
scp -i "RUTA_CLAVE.pem" -r certs/ secrets/ .env docker-compose.yml deploy.sh ec2-user@IP_EC2:/home/ec2-user/tp-1/
ssh -i "RUTA_CLAVE.pem" ec2-user@IP_EC2 'bash ~/tp-1/deploy.sh'
```

`IP_EC2` y la ruta de la clave deben ajustarse al entorno. Los scripts se ejecutan con Bash; en Windows se utiliza un entorno que lo proporcione, como WSL o Git Bash.

Dentro de EC2, [deploy.sh](deploy.sh):

1. Comprueba los archivos requeridos y restringe permisos de los privados.
2. Instala Docker, habilita su servicio y comprueba curl.
3. Descarga el plugin Compose y verifica el checksum SHA-256 antes de instalarlo.
4. Valida Compose y las ocho referencias de imágenes.
5. Ejecuta `pull`, `up -d` y `ps`.
6. Exige ocho contenedores en ejecución y verifica las rutas HTTPS.

El script no compila aplicaciones ni elimina volúmenes. Se conserva la carpeta `~/tp-1` porque Compose deduce de ella el nombre del proyecto, relevante para reutilizar su volumen. El instalador contempla distintas arquitecturas para Compose, pero las imágenes del build actual están preparadas para amd64.

Para consultar el estado y diagnosticar un servicio, desde esa carpeta:

```bash
sudo docker compose ps
sudo docker compose logs --tail 100 tp1-api-clientes
```

## 8. Verificaciones y evidencias funcionales

El despliegue comprueba el estado de los contenedores y las respuestas de las rutas. Las verificaciones HTTP se ejecutan desde EC2 contra `https://127.0.0.1`, con reintentos para contemplar el tiempo de arranque.

![Contenedores en ejecución](docs/evidencias/01-contenedores-ec2.png)

| Ruta | Código esperado |
|---|---|
| `/` | 200 |
| `/api/clientes` | 200 |
| `/api/pagos` | 200 |
| `/api/facturas` | 200 |
| `/api/transacciones` | 200 |
| `/api/tarjetas` | 200 |
| `/dashboard/` sin credenciales | 401 |

![Verificación HTTPS](docs/evidencias/02-verificacion-https.png)

El script comprueba códigos HTTP, no el contenido JSON ni todas las operaciones. Utiliza `curl -k` por el certificado autofirmado y no verifica su confianza. La consulta local tampoco reemplaza una prueba de acceso desde Internet.

Las pruebas desde la interfaz complementan esa comprobación. La documentación previa registra una operación de Pagos con conversión ARS/USD y una transacción con la IP `8.8.4.4`, cuyo país obtenido fue `United States`. En la nueva prueba se comprobó el acceso público a la web, se renovaron las capturas de las cinco secciones y se accedió al dashboard después de preparar el usuario `camila`.

### Prueba de persistencia

Se creó el cliente `Prueba Persistencia`, con ID 4, y se recreó únicamente el contenedor de MariaDB, conservando su volumen:

```bash
cd ~/tp-1
sudo docker compose up -d --no-deps --force-recreate tp1-db
```

Al recargar Clientes, el registro seguía disponible con el mismo ID y sus datos. Esta prueba verifica la conservación de un registro tras reemplazar el contenedor utilizando el volumen existente. Se realizó por separado; no forma parte de las comprobaciones automáticas de `deploy.sh`.

### Pagos y Transacciones: servicios externos

Pagos consulta una API de tipo de cambio y calcula el valor en USD. Transacciones consulta `ipapi.co` y utiliza `IPAPI_TOKEN` desde el entorno. Ambas consultas tienen un tiempo de espera de cinco segundos y permiten guardar el registro sin el campo enriquecido si el proveedor falla.

<img src="docs/evidencias/06-web-pagos.png" alt="Pagos y conversión" width="700">

<img src="docs/evidencias/08-web-transacciones.png" alt="Transacciones y país de origen" width="700">

### Otras funcionalidades

Las siguientes capturas documentan las secciones de Tarjetas y Facturas. La sección Clientes se muestra junto a la arquitectura. Las imágenes corresponden a las pruebas realizadas, no a una comprobación en vivo de AWS.

<img src="docs/evidencias/04-web-tarjetas.png" alt="Gestión de tarjetas" width="700">

<img src="docs/evidencias/05-web-facturas.png" alt="Gestión de facturas" width="700">

## 9. Problemas encontrados y soluciones

### Conexiones HTTPS desde Go

La consulta de geolocalización fallaba por falta de certificados CA en la imagen. Se incorporó `ca-certificates` a Alpine para verificar las conexiones con el proveedor externo. Estos certificados de confianza son distintos del certificado autofirmado utilizado para recibir HTTPS en Traefik.

### Límite de consultas e IP inválida

El proveedor de geolocalización alcanzó su límite de consultas. Se configuró el token mediante `IPAPI_TOKEN`, manteniéndolo fuera del código y de Git. Otra prueba utilizó `3` como IP y guardó la transacción sin país; se repitió con `8.8.4.4` y se agregó una comprobación de IPv4 en la web. Esa validación no está implementada de la misma manera en el manejador de creación de Go.

### Credenciales persistidas en MariaDB

Cambiar las credenciales de `.env` no actualizaba los usuarios existentes: el volumen conservaba el estado anterior y las variables de inicialización se aplican al crear un directorio de datos nuevo. Durante pruebas sin información que conservar se recreó el volumen. En una base con datos, eliminarlo no es una solución adecuada: corresponde ajustar las credenciales en MariaDB.

### Tiempos de arranque y Bad Gateway

Las APIs podían iniciar mientras MariaDB todavía no aceptaba conexiones; Traefik también podía recibir solicitudes antes de que su destino estuviera disponible. Se esperó la inicialización y se incorporaron reintentos en las verificaciones. `depends_on` establece orden de inicio, no disponibilidad.

### Scripts de Windows y permisos SSH

Los finales de línea CRLF produjeron errores al ejecutar scripts en Linux. Se convirtieron a LF y se configuró `.gitattributes`. Para SSH se restringieron los permisos de la PEM; al usar WSL se guardó una copia en su directorio personal con permisos 600.

### Herramientas y acceso a la instancia

La instalación del paquete completo `curl` entraba en conflicto con `curl-minimal` en Amazon Linux. El deploy se ajustó para instalar Docker y utilizar el curl disponible. El plugin Compose se descarga por separado.

Una instancia del laboratorio no permitía SSH por su configuración de red y clave. Se creó una instancia propia con el par de claves y las reglas necesarias. Para operar Docker, el deploy actual utiliza `sudo docker`.

### Contenedores anteriores

Durante pruebas locales aparecieron conflictos con nombres de contenedores de ejecuciones previas. Se retiraron los que ya no correspondían al entorno y se mantuvo atención al nombre del proyecto Compose para evitar utilizar un volumen distinto al esperado.

## 10. Resultado y documentación complementaria

La nueva prueba desde cero documenta la publicación de las ocho imágenes con el tag `prueba-2026-10-11`, la ejecución de los ocho servicios en una EC2 nueva, las respuestas HTTPS esperadas, el acceso público al frontend y al dashboard y la persistencia del cliente de prueba después de recrear MariaDB. La documentación de pruebas anteriores registra además las consultas externas de Pagos y Transacciones.

Los scripts separan construcción, preparación y despliegue. La configuración privada se suministra al ejecutar los servicios; las credenciales reales y las claves privadas se mantienen fuera del repositorio y de las imágenes públicas. La prueba realizada no constituye una validación exhaustiva de todas las operaciones de las APIs.

Los siguientes documentos amplían los procedimientos. La arquitectura, el flujo de despliegue, las evidencias y los problemas principales quedan desarrollados en este README:

- [DEPLOY.md](DEPLOY.md): procedimiento de construcción, preparación y despliegue.
- [SEGURIDAD.md](SEGURIDAD.md): medidas de acceso y tratamiento de archivos privados.
- [AWS_EC2.md](AWS_EC2.md): configuración y registro de la prueba en AWS.
- [ERRORES.md](ERRORES.md): detalle de incidencias documentadas.
- [Enunciado del TP](Enunciado-TP-Parte-1.md): requisitos y alcance de la entrega.
