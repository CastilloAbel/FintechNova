# Errores encontrados y soluciones

Durante la dockerización, integración y despliegue de FinTech Nova se encontraron distintos inconvenientes. A continuación se documentan los principales problemas y las soluciones aplicadas.

## 1. API Transacciones - certificados HTTPS

### Problema

Al dockerizar la API de Transacciones, desarrollada en Go, la consulta al servicio externo de geolocalización no funcionaba correctamente porque el contenedor no contaba con los certificados necesarios para realizar conexiones HTTPS.

### Solución

Se instalaron los certificados CA dentro de la imagen agregando al Dockerfile:

```dockerfile
RUN apk add --no-cache ca-certificates
```

Luego de reconstruir la imagen, el contenedor pudo establecer correctamente conexiones HTTPS con el servicio externo.

---

## 2. API Transacciones - límite de consultas de IPAPI

### Problema

Una vez solucionado el problema de certificados, el servicio externo de geolocalización comenzó a responder con un error de `RateLimit`.

La cuota disponible de la API externa se había agotado y esto impedía continuar con las pruebas.

### Solución

Se solicitó una API key a IPAPI.

La aplicación en Go fue modificada para obtener el token desde una variable de entorno en lugar de incluirlo directamente en el código.

Se configuró:

```text
IPAPI_TOKEN
```

El token se almacena en el archivo `.env`, que no se versiona.

De esta manera se pudo volver a consumir el servicio externo sin exponer la credencial dentro del código ni de la imagen Docker.

---

## 3. MariaDB - credenciales anteriores almacenadas en el volumen

### Problema

Durante las pruebas locales algunas APIs obtenían errores de acceso a MariaDB aunque las credenciales del `.env` eran correctas.

### Causa

MariaDB utiliza las variables de inicialización solamente cuando crea por primera vez su directorio de datos.

El volumen persistente había sido creado anteriormente utilizando otras credenciales. Modificar posteriormente el `.env` no modificaba los usuarios almacenados dentro de la base existente.

### Solución

Durante las pruebas locales, donde no existían datos que fuera necesario conservar, se recreó el volumen:

```sh
docker compose down -v
docker compose up -d
```

Este procedimiento elimina los datos persistidos, por lo que no debe utilizarse en un entorno que contenga información que se quiera conservar.

---

## 4. MariaDB - scripts con finales de línea de Windows

### Problema

Uno de los scripts de inicialización de MariaDB produjo un error similar a:

```text
/bin/bash^M
```

### Causa

El archivo había sido guardado utilizando finales de línea `CRLF` de Windows, mientras que el contenedor Linux esperaba `LF`.

### Solución

Se convirtieron los archivos a formato `LF` y se configuró el repositorio para evitar nuevamente el problema mediante `.gitattributes`.

---

## 5. APIs iniciadas antes de que MariaDB estuviera disponible

### Problema

Durante algunas pruebas los contenedores de las APIs ya estaban iniciados, pero todavía no podían conectarse a MariaDB.

En particular se observaron errores de conexión como `ECONNREFUSED`.

### Causa

Que el contenedor de MariaDB se encuentre iniciado no significa necesariamente que la base ya esté preparada para recibir conexiones.

### Solución

Se esperó a que MariaDB completara su inicialización y se volvieron a realizar las pruebas.

La configuración `restart: always` también permite que los servicios vuelvan a iniciarse ante fallos durante el arranque.

---

## 6. Bad Gateway inmediatamente después de iniciar los servicios

### Problema

Inmediatamente después de recrear algunos contenedores, Traefik podía responder temporalmente con `Bad Gateway`.

### Causa

Traefik ya estaba disponible mientras que la API correspondiente todavía estaba iniciándose.

### Solución

Se esperó a que el servicio terminara de iniciar y se volvió a realizar la solicitud.

El script de despliegue contempla esta situación realizando varios intentos durante la verificación.

---

## 7. Permisos de la clave SSH de AWS

### Problema

Al intentar utilizar la clave `.pem` para conectarse a la instancia EC2, SSH rechazó inicialmente el archivo por tener permisos demasiado abiertos.

### Solución

En Windows se restringieron los permisos del archivo mediante `icacls`, permitiendo su lectura únicamente al usuario correspondiente.

La conexión SSH pudo realizarse correctamente luego de ajustar los permisos.

---

## 8. Clave PEM utilizada desde WSL

### Problema

Aunque la clave funcionaba correctamente desde PowerShell, al utilizarla directamente desde `/mnt/c/...` en WSL, OpenSSH continuaba rechazándola por sus permisos.

### Causa

Los permisos de archivos ubicados en el sistema de archivos de Windows no se representan de la misma manera dentro de WSL.

### Solución

Se copió la clave al directorio personal de WSL:

```sh
cp "/mnt/c/ruta/FinTech-Nova.pem" ~/FinTech-Nova.pem
chmod 600 ~/FinTech-Nova.pem
```

Luego se utilizó esa copia para realizar el despliegue:

```sh
export SSH_KEY="$HOME/FinTech-Nova.pem"
```

---

## 9. Instalación de Docker Compose en Amazon Linux 2023

### Problema

Durante las primeras pruebas de preparación de EC2 no se encontró Docker Compose disponible directamente de la forma esperada mediante el gestor de paquetes.

### Solución

El proceso de despliegue instala el plugin de Docker Compose cuando es necesario.

De esta manera una instancia nueva puede ser preparada automáticamente por `deploy.sh`.

---

## 10. Conflicto entre curl y curl-minimal en Amazon Linux 2023

### Problema

Durante la prueba real de `deploy.sh` sobre una instancia nueva de Amazon Linux 2023, el script intentaba ejecutar:

```sh
sudo dnf install -y docker curl
```

La instalación falló porque Amazon Linux ya incluía `curl-minimal`, que entraba en conflicto con el paquete completo `curl`.

### Solución

No era necesario reemplazar `curl-minimal`, ya que proporcionaba la funcionalidad requerida por el script.

Se modificó la preparación de EC2 a:

```sh
sudo dnf install -y docker
```

Luego de este cambio el despliegue automático continuó correctamente.

---

## 11. Acceso al socket de Docker en EC2

### Problema

Durante las primeras pruebas manuales en EC2 se obtuvieron errores de permisos al intentar ejecutar Docker con el usuario de la instancia.

### Solución

Se otorgaron al usuario los permisos correspondientes para utilizar Docker y se volvió a iniciar la sesión para que los cambios tuvieran efecto.

---

## 12. Instancia de AWS Academy sin acceso SSH

### Problema

Una instancia generada automáticamente por el laboratorio de AWS Academy no permitía realizar la conexión SSH.

### Causa

El Security Group de esa instancia no tenía habilitado el puerto `22` para nuestra IP y la instancia tampoco había sido creada utilizando nuestra clave SSH.

### Solución

Se creó una nueva instancia EC2 propia para el TP, configurando desde el inicio:

```text
SSH    TCP 22   -> IP autorizada
HTTPS  TCP 443  -> 0.0.0.0/0
```

También se seleccionó una nueva clave `.pem`.

---

## 13. Docker Compose - contenedores anteriores

### Problema

Durante las pruebas locales aparecieron conflictos de nombres con contenedores creados en ejecuciones anteriores.

### Solución

Se eliminaron los contenedores anteriores que ya no correspondían al despliegue actual y se volvió a ejecutar Docker Compose.

Cuando fue necesario también se utilizaron las opciones de Compose para eliminar contenedores huérfanos.

---

## 14. API Transacciones - IP de prueba inválida

### Problema

Durante la validación final en AWS se creó una transacción utilizando `3` como IP de origen.

La transacción se almacenó correctamente, pero el campo país quedó vacío.

### Causa

`3` no representa una dirección IP válida para realizar la consulta de geolocalización.

### Verificación

Se realizó nuevamente la prueba utilizando una dirección IP válida:

```text
8.8.4.4
```

La API respondió correctamente obteniendo:

```text
United States
```

Esto permitió comprobar el funcionamiento de la integración con el servicio externo de geolocalización.

---

## Componentes sin incidencias importantes

### Traefik

La implementación se realizó siguiendo la documentación oficial.

Se creó un archivo YAML dinámico por servicio y posteriormente una imagen propia de Traefik mediante un Dockerfile. Esto permite incluir la configuración de routing dentro de la imagen y evita tener que copiar manualmente cada archivo YAML a la instancia EC2.

También se configuró correctamente HTTPS mediante un certificado autofirmado.

### Web

El frontend fue dockerizado y publicado detrás de Traefik.

### API Facturas

Se utilizó una imagen multistage para separar la etapa de compilación de la imagen utilizada en ejecución.

Al estar desarrollada en Java, su construcción e inicio pueden requerir más tiempo que algunos de los otros servicios.

### API Tarjetas

Se implementó mediante una imagen Docker multistage y no presentó inconvenientes importantes durante las pruebas.

---

## Resultado final

Luego de aplicar estas correcciones se logró desplegar correctamente la solución completa en Amazon EC2.

La verificación automática confirmó:

```text
OK HTTPS /
OK HTTPS /api/clientes
OK HTTPS /api/pagos
OK HTTPS /api/facturas
OK HTTPS /api/transacciones
OK HTTPS /api/tarjetas
```

Los ocho contenedores quedaron en ejecución y la aplicación pudo utilizarse correctamente mediante HTTPS.

## Estado de las pruebas de noviembre 2026

En el despliegue histórico compartido, el job finalizó con `Job succeeded`; no se observa un error de ejecución del deploy. El log muestra advertencias de OpenSSH por intercambio de claves no poscuántico: no bloquearon la transferencia ni el despliegue. En esa configuración histórica, Trivy aparecía con advertencia y `allow_failure: true`; esa política fue reemplazada. La configuración vigente bloquea el pipeline ante hallazgos HIGH/CRITICAL. Se incorporaron pruebas de API Clientes con mocks para validar rutas antes del Build sin depender de MariaDB.


## 16. CI/CD — fallo inicial del smoke test de API Tarjetas

**Problema:** el job `test_api_tarjetas` falló con `curl: (7) Failed to connect to 127.0.0.1 port 18084`, aunque el log de .NET mostraba que la API iniciaba en `http://0.0.0.0:8080`.

**Causa:** el test consultaba un puerto distinto al de la aplicación y el tiempo de compilación retrasaba el arranque.

**Solución:** modificar `aplicaciones-contenedores/api-tarjetas/tests/smoke.sh` para compilar primero (`dotnet build`), ejecutar sin recompilar (`dotnet run --no-build`), fijar el puerto `8080` y esperar hasta que responda el endpoint. **Resultado:** `test_api_tarjetas` en verde en el pipeline #16409.

## 17. CI/CD — Trivy detectó paquetes vulnerables en dos imágenes

**Problema:** `analizar_imagenes_trivy` quedaba en naranja por cuatro detecciones HIGH (`CVE-2026-109518`) en MariaDB y API Facturas.

**Causa:** paquetes `apt` y bibliotecas relacionadas en las imágenes base requerían actualizaciones de seguridad. Durante el incidente se habilitó temporalmente `allow_failure: true`, por lo que el job podía mostrar advertencia sin bloquear el pipeline. Esa excepción temporal ya no representa la política vigente.

**Solución:** agregar actualización selectiva de `apt` y las bibliotecas APT correspondientes en los Dockerfiles de DB, Facturas y Tarjetas; reconstruir las imágenes y volver a ejecutar Trivy. El equipo reporta una ejecución posterior exitosa. Sin embargo, los artifacts locales actuales corresponden al tag `349306ed` y todavía contienen el CVE en las imágenes de DB y Facturas, por lo que no se deben presentar como el resultado post-fix. La política actual bloquea los hallazgos HIGH/CRITICAL corregibles y usa `--ignore-unfixed` para excluir los que no tienen fix disponible; revisar los artifacts del pipeline/tag reconstruido para confirmar la remediación y procedencia. El contexto, la línea de tiempo y las acciones preventivas están en [el postmortem](docs/postmortems/PM-2026-11-trivy-cve-discovery.md) y el procedimiento está en [el runbook](docs/runbooks/runbook-trivy-vulnerabilities.md).

**Pendiente separado:** revisar el aviso moderado `NU1902` de `MySqlConnector 2.3.7` en API Tarjetas.
