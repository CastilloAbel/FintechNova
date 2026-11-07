# FinTech Nova — Trabajo Práctico DevOps 2026
## Parte 2 — Integración y Despliegue Continuo (CI/CD)

**Grupo 19 — Camila Gea (82327) y Abel Castillo (90322)**

## 1. Introducción

En la primera parte del Trabajo Práctico se desarrolló la infraestructura de FinTech Nova mediante Docker y Docker Compose, integrando cinco APIs, una interfaz web, una base de datos MariaDB y Traefik como proxy inverso.

El despliegue se realizaba mediante scripts ejecutados manualmente, utilizando imágenes publicadas en Docker Hub.

En esta segunda parte se incorporó un pipeline de **Integración y Despliegue Continuo (CI/CD)** mediante GitLab CI/CD.

El objetivo es automatizar la construcción, validación, análisis de seguridad, publicación y despliegue de los componentes de la aplicación en AWS EC2.

Con esta implementación se busca reducir las tareas manuales, mejorar la reproducibilidad del despliegue, detectar problemas antes de publicar cambios y facilitar la trazabilidad de las versiones.

## 2. Arquitectura de la solución

Se mantiene la arquitectura de ocho contenedores implementada en la Parte 1.

| Servicio | Tecnología | Función |
|---|---|---|
| tp1-web | JavaScript / Vite | Interfaz web |
| tp1-api-clientes | Python / Flask | Gestión de clientes |
| tp1-api-pagos | Node.js / Express | Gestión de pagos |
| tp1-api-facturas | Java / Spring Boot | Gestión de facturas |
| tp1-api-transacciones | Go | Gestión de transacciones |
| tp1-api-tarjetas | .NET / ASP.NET Core | Gestión de tarjetas |
| tp1-db | MariaDB | Persistencia de datos |
| traefik | Traefik | Proxy inverso y HTTPS |

Todos los servicios se ejecutan mediante Docker Compose y se comunican a través de la red interna `proxy`.

Traefik centraliza el acceso externo mediante HTTPS por el puerto 443. Las APIs y MariaDB no publican sus puertos directamente hacia Internet.

El archivo `docker-compose.yml` permite desplegar los ocho servicios utilizando las imágenes generadas por el pipeline.

## 3. Implementación de GitLab CI/CD

Se incorporó el archivo `.gitlab-ci.yml` en la raíz del repositorio.

Este archivo define las etapas, los jobs, los runners y las acciones que se ejecutan durante el pipeline.

El pipeline está organizado en cuatro etapas:

1. **Test:** comprobación inicial del pipeline.
2. **Build:** construcción y publicación de las imágenes Docker.
3. **Security:** validación de configuración, análisis de código, imágenes y secretos.
4. **Deploy:** despliegue de la aplicación en AWS EC2.

### 3.1. Flujo del pipeline

```text
Desarrollador
     |
     v
Push al repositorio GitLab
     |
     v
+-------------------------+
|         TEST            |
|    prueba_pipeline      |
+-------------------------+
     |
     v
+-------------------------+
|         BUILD           |
|                         |
|  build_traefik          |
|  build_db               |
|  build_clientes         |
|  build_pagos            |
|  build_facturas         |
|  build_transacciones    |
|  build_tarjetas         |
|  build_web              |
|                         |
|  Jobs independientes    |
|  ejecutables en paralelo|
+-------------------------+
     |
     v
GitLab Container Registry
     |
     v
+-------------------------+
|        SECURITY         |
|                         |
|  validar_compose        |
|  analizar_dockerfiles   |
|  analizar_codigo_semgrep|
|  analizar_imagenes_trivy|
|  analizar_archivos_yaml |
|  detectar_secretos      |
+-------------------------+
     |
     v
+-------------------------+
|         DEPLOY          |
|                         |
|       deploy_aws        |
|                         |
| Inicio manual actual    |
| Ejecución automatizada  |
+-------------------------+
     |
     v
AWS EC2
     |
     v
Docker Compose
     |
     v
8 contenedores en ejecución
     |
     v
Verificaciones HTTPS
```

Los jobs de una misma etapa pueden ejecutarse en paralelo, dependiendo de la disponibilidad de los runners de GitLab.

Las etapas se ejecutan en el orden definido en `.gitlab-ci.yml`.

## 4. Etapa Test

La primera etapa contiene el job `prueba_pipeline`.

Su objetivo es comprobar que GitLab CI/CD puede iniciar correctamente la ejecución del pipeline.

Actualmente realiza una validación básica mediante mensajes de confirmación.

Esta etapa no ejecuta todavía pruebas unitarias ni pruebas funcionales automatizadas de las APIs.

Como mejora futura, se podrían incorporar pruebas específicas para cada microservicio.

## 5. Etapa Build

La etapa Build construye las ocho imágenes Docker necesarias para ejecutar FinTech Nova.

Se definió una plantilla reutilizable llamada `.build_image`, utilizada por los jobs de construcción.

Cada job establece el Dockerfile, el contexto de construcción y el nombre de la imagen correspondiente.

Las imágenes se construyen para la arquitectura `linux/amd64`.

### 5.1. Publicación de imágenes

A diferencia de la Parte 1, donde se utilizaba Docker Hub, las imágenes de esta entrega se publican en **GitLab Container Registry**.

Cada imagen se identifica mediante dos etiquetas:

- `latest`: referencia a la última imagen publicada con esa etiqueta.
- `$CI_COMMIT_SHORT_SHA`: identifica la versión construida a partir de un commit específico.

La utilización del identificador del commit permite relacionar las imágenes con el código fuente que las generó.

El pipeline utiliza las variables automáticas de GitLab:

- `CI_REGISTRY`
- `CI_PROJECT_PATH`
- `CI_REGISTRY_USER`
- `CI_REGISTRY_PASSWORD`
- `CI_COMMIT_SHORT_SHA`

La autenticación se realiza mediante `docker login`, enviando la contraseña por entrada estándar para evitar escribirla directamente en el comando.

### 5.2. Ventajas de la automatización

La construcción ya no depende de que un integrante ejecute manualmente `build.sh` en su computadora.

GitLab se encarga de construir y publicar las imágenes siguiendo la configuración del repositorio.

Esto permite reproducir el proceso y mantener un registro de cada ejecución.

## 6. Etapa Security

Se incorporaron herramientas de análisis estático, validación de configuración, detección de secretos y análisis de vulnerabilidades.

El objetivo es identificar problemas antes del despliegue.

| Herramienta | Job | Función |
|---|---|---|
| Docker Compose | validar_compose | Validar la configuración de los servicios |
| Hadolint | analizar_dockerfiles | Analizar buenas prácticas de Dockerfiles |
| Semgrep | analizar_codigo_semgrep | Detectar problemas de seguridad en el código |
| Trivy | analizar_imagenes_trivy | Analizar vulnerabilidades de imágenes Docker |
| Yamllint | analizar_archivos_yaml | Validar archivos YAML |
| Gitleaks | detectar_secretos | Detectar posibles secretos en el repositorio |

### 6.1. Hadolint

Analiza los ocho Dockerfiles utilizados por el proyecto.

Permite identificar errores y problemas relacionados con buenas prácticas de construcción de imágenes.

El pipeline utiliza el umbral `error` para determinar si un hallazgo provoca el fallo del job.

### 6.2. Semgrep

Realiza análisis estático del código fuente mediante reglas automáticas.

Está configurado para considerar los hallazgos de severidad `ERROR`.

Genera el archivo `semgrep-report.json`, que puede descargarse desde los artifacts del pipeline.

### 6.3. Trivy

Analiza las ocho imágenes Docker publicadas en GitLab Container Registry.

Se configura para detectar vulnerabilidades de severidad `HIGH` y `CRITICAL`, ignorando las que no tienen una corrección disponible.

Genera un reporte JSON por imagen.

**Configuración actual:** el job utiliza `allow_failure: true`.

Esto significa que, aunque Trivy detecte vulnerabilidades y el job falle, GitLab puede permitir que el pipeline continúe.

Se decidió mantener temporalmente esta configuración durante las pruebas, para poder analizar los hallazgos sin impedir el despliegue académico.

Como mejora futura, se propone revisar las vulnerabilidades detectadas, actualizar las imágenes o dependencias afectadas y establecer una política de bloqueo para vulnerabilidades críticas corregibles.

### 6.4. Yamllint

Valida los archivos YAML utilizados por el proyecto, incluyendo:

- `.gitlab-ci.yml`
- `docker-compose.yml`
- Configuración YAML de Traefik.

Permite detectar problemas de formato y sintaxis antes de ejecutar el despliegue.

### 6.5. Gitleaks

Analiza el repositorio para identificar posibles credenciales, contraseñas, tokens o claves expuestas.

Esto ayuda a evitar que información sensible quede publicada accidentalmente en Git.

### 6.6. Reportes de seguridad

Los jobs de análisis generan artifacts descargables desde GitLab.

Los reportes se conservan durante una semana, según la configuración del pipeline.

Estos archivos permiten revisar los resultados de cada ejecución sin incorporarlos directamente al repositorio.

Los hallazgos y las decisiones de seguridad se amplían en `SEGURIDAD.md` y `ANALISIS.md`.

## 7. Etapa Deploy — Despliegue en AWS EC2

La última etapa contiene el job `deploy_aws`.

Su función es desplegar las imágenes construidas por el pipeline en una instancia EC2 de AWS Academy.

### 7.1. Inicio manual y automatización

Actualmente, el job `deploy_aws` utiliza la configuración `when: manual`.

Esta decisión se tomó para controlar cuándo realizar el despliegue, debido a que el entorno de AWS Academy es temporal y la instancia EC2 debe estar activa.

**Es importante distinguir el inicio del job del proceso de despliegue.**

Actualmente se inicia manualmente el job desde GitLab, pero una vez iniciado, todas las tareas de preparación, transferencia, ejecución y verificación se realizan automáticamente.

Para habilitar también el inicio automático, se puede modificar la configuración del job, reemplazando `when: manual` por `when: on_success` en las reglas correspondientes.

De esta manera, GitLab podría iniciar el despliegue cuando finalicen las etapas anteriores, sin necesidad de presionar manualmente el botón de ejecución.

Esta modificación no requiere rediseñar el proceso de despliegue, ya que las acciones necesarias están implementadas.

Sin embargo, para que funcione correctamente, deben estar disponibles la instancia EC2, la conectividad SSH y las variables de configuración.

Además, actualmente Trivy tiene permitido fallar sin bloquear el pipeline, por lo que la automatización del inicio no implica que todos los análisis de seguridad deban haber finalizado sin hallazgos.

### 7.2. Preparación automática de EC2

El pipeline se conecta a la instancia mediante SSH y ejecuta el script `setup-ec2.sh`.

Este script se encarga de preparar el entorno necesario para ejecutar los contenedores.

Entre sus tareas se encuentran:

- Comprobar la instalación de Docker.
- Instalar Docker cuando sea necesario.
- Habilitar e iniciar el servicio Docker.
- Comprobar la disponibilidad de Docker Compose.
- Instalar el plugin Docker Compose cuando sea necesario.

Esto permite trabajar con una instancia nueva sin instalar manualmente todas las herramientas.

### 7.3. Transferencia de imágenes

El pipeline utiliza GitLab Container Registry como origen de las imágenes.

El procedimiento es el siguiente:

1. El runner inicia sesión en GitLab Container Registry.
2. Descarga cada imagen correspondiente al commit.
3. Exporta la imagen mediante `docker save`.
4. La transfiere por SSH a EC2.
5. En EC2, `docker load` incorpora la imagen al Docker local.

Este procedimiento se repite para las ocho imágenes.

**La instancia EC2 no necesita autenticarse directamente contra GitLab Container Registry**, porque las imágenes se transfieren desde el runner.

### 7.4. Configuración del entorno

El pipeline prepara automáticamente los archivos necesarios para ejecutar la aplicación.

Entre ellos:

- `docker-compose.yml`
- `deploy.sh`
- `.env`
- Certificado HTTPS
- Clave privada TLS
- Archivo de autenticación del dashboard

Las credenciales se obtienen desde las variables de GitLab CI/CD y no se incluyen directamente en el repositorio.

El archivo `.env` se genera durante la ejecución y se transfiere a EC2.

También se genera un certificado autofirmado mediante OpenSSL para habilitar HTTPS.

### 7.5. Inicio de los contenedores

Una vez transferidas las imágenes y la configuración, el pipeline ejecuta `deploy.sh` en EC2.

Este script utiliza Docker Compose para iniciar los ocho servicios.

El despliegue utiliza las imágenes previamente transferidas, sin necesidad de reconstruirlas dentro de la instancia.

Los servicios ejecutados son:

- Traefik
- MariaDB
- API Clientes
- API Pagos
- API Facturas
- API Transacciones
- API Tarjetas
- Web

Se mantienen las medidas de la Parte 1, incluyendo la red interna, los límites de recursos, la persistencia de MariaDB y el acceso externo mediante HTTPS.

## 8. Variables de GitLab CI/CD

Para ejecutar el despliegue se utilizan variables configuradas en GitLab.

Estas permiten separar la configuración del entorno y los datos sensibles del código fuente.

| Variable | Finalidad |
|---|---|
| AWS_EC2_HOST | Dirección pública de EC2 |
| AWS_EC2_USER | Usuario SSH |
| AWS_SSH_PRIVATE_KEY | Clave privada SSH |
| DB_USER | Usuario de MariaDB |
| DB_PASSWORD | Contraseña de aplicación |
| MYSQL_ROOT_PASSWORD | Contraseña del usuario root |
| DASHBOARD_USER | Usuario del dashboard |
| DASHBOARD_PASSWORD | Contraseña del dashboard |
| IPAPI_TOKEN | Token de la API externa |

Las variables sensibles deben configurarse utilizando los mecanismos de protección disponibles en GitLab, como variables enmascaradas y protegidas cuando corresponda.

No deben incorporarse credenciales reales, archivos PEM ni claves privadas al repositorio.

Cuando se crea una nueva instancia de AWS Academy, es necesario actualizar los datos de conexión correspondientes.

## 9. Verificaciones automáticas

Después de iniciar los contenedores, el script de despliegue verifica que los servicios respondan correctamente.

Las comprobaciones se realizan mediante solicitudes HTTPS.

| Ruta | Resultado esperado |
|---|---|
| `/` | HTTP 200 |
| `/api/clientes` | HTTP 200 |
| `/api/pagos` | HTTP 200 |
| `/api/facturas` | HTTP 200 |
| `/api/transacciones` | HTTP 200 |
| `/api/tarjetas` | HTTP 200 |
| `/dashboard/` sin credenciales | HTTP 401 |

El código `401` del dashboard es esperado, porque demuestra que se requiere autenticación.

Como se utiliza un certificado autofirmado, las verificaciones emplean `curl -k`.

Estas pruebas confirman la disponibilidad de las rutas, aunque no reemplazan pruebas funcionales completas de cada API.

## 10. Prueba exitosa en AWS

Se realizó una prueba del pipeline utilizando una instancia EC2 de AWS Academy.

Durante la ejecución, el pipeline:

1. Preparó automáticamente Docker y Docker Compose.
2. Transfirió las ocho imágenes desde el runner.
3. Generó y transfirió los archivos de configuración.
4. Inició los ocho contenedores.
5. Ejecutó las verificaciones HTTPS.
6. Finalizó correctamente el job de despliegue.

La prueba registrada utilizó la siguiente dirección pública:

`54.167.87.63`

Esta dirección corresponde a una instancia temporal del laboratorio y puede cambiar en futuras sesiones.

### 10.1. Resultado de las verificaciones

```text
OK HTTPS / (HTTP 200)
OK HTTPS /api/clientes (HTTP 200)
OK HTTPS /api/pagos (HTTP 200)
OK HTTPS /api/facturas (HTTP 200)
OK HTTPS /api/transacciones (HTTP 200)
OK HTTPS /api/tarjetas (HTTP 200)
OK HTTPS /dashboard/ (HTTP 401)

Despliegue y verificaciones completados.
Job succeeded
```

Además, se comprobó el acceso a la aplicación desde el navegador y se ingresó correctamente al dashboard de Traefik utilizando las credenciales configuradas.

### 10.2. Evidencias

Para la entrega se deben incorporar capturas correspondientes a una misma sesión de AWS Academy:

- Pipeline de GitLab y sus etapas.
- Job `deploy_aws` finalizado correctamente.
- Imágenes publicadas en GitLab Container Registry.
- Instancia EC2 en ejecución.
- Ocho contenedores iniciados.
- Aplicación funcionando mediante HTTPS.
- Dashboard de Traefik protegido mediante autenticación.

**Pendiente:** incorporar las capturas finales en `docs/evidencias/` y enlazarlas desde este documento.

## 11. Problemas encontrados durante la implementación

Durante el desarrollo del pipeline se presentaron distintos inconvenientes.

### 11.1. Configuración YAML

Se encontraron errores de formato y validación en `.gitlab-ci.yml`.

Se corrigió la estructura del archivo hasta lograr que GitLab interpretara correctamente las etapas y los jobs.

### 11.2. Construcción y publicación de imágenes

Durante las pruebas se presentaron inconvenientes relacionados con la construcción y disponibilidad de algunas imágenes.

Se revisaron las referencias, los tags y los jobs de publicación para garantizar que el despliegue utilizara las imágenes del commit correspondiente.

### 11.3. Acceso SSH a EC2

Al trabajar con nuevas instancias de AWS Academy fue necesario revisar la clave SSH, el usuario, la dirección IP y las reglas del Security Group.

Una vez corregida la configuración, el pipeline pudo conectarse a la instancia.

### 11.4. Permisos del archivo de autenticación de Traefik

Durante una ejecución, el despliegue falló al intentar modificar los permisos del archivo `secrets/dashboard_users`.

El problema se resolvió ajustando el propietario y los permisos del archivo para permitir su lectura por Traefik.

Después de aplicar la corrección, el despliegue finalizó correctamente.

El detalle de los errores y sus soluciones se documenta en `ERRORES.md`.

## 12. Mejoras respecto de la Parte 1

| Aspecto | Parte 1 | Parte 2 |
|---|---|---|
| Construcción | Script local `build.sh` | Pipeline GitLab |
| Publicación | Docker Hub | GitLab Container Registry |
| Versionado de imágenes | Tag definido manualmente | Tag asociado al commit |
| Validaciones | Pruebas principalmente manuales | Jobs automáticos |
| Seguridad | Configuración y controles básicos | Semgrep, Trivy, Hadolint, Yamllint y Gitleaks |
| Preparación de EC2 | Scripts ejecutados manualmente | Preparación desde GitLab |
| Transferencia | Archivos copiados desde la PC | Transferencia automatizada por SSH |
| Despliegue | Inicio manual desde la PC | Job de GitLab con inicio manual configurable |
| Verificación | Comprobaciones del script | Verificaciones ejecutadas desde el pipeline |
| Trazabilidad | Registros y capturas de pruebas | Pipelines, jobs, commits y artifacts |

La mejora principal es la centralización del proceso de integración y despliegue en GitLab.

Esto permite ejecutar los mismos procedimientos de forma reproducible y reduce la dependencia de configuraciones locales.

## 13. Mejoras futuras

Aunque se alcanzó el objetivo de implementar CI/CD, se identificaron posibles mejoras:

1. **Automatizar el inicio del deploy:** cambiar la configuración manual por ejecución automática cuando el entorno esté disponible.
2. **Incorporar pruebas unitarias y de integración:** ampliar la etapa Test para validar el comportamiento de las APIs.
3. **Fortalecer la política de seguridad:** revisar los hallazgos de Trivy y definir cuáles deben bloquear el despliegue.
4. **Utilizar certificados confiables:** reemplazar el certificado autofirmado por uno emitido por una autoridad certificadora.
5. **Mejorar la disponibilidad:** incorporar mecanismos de recuperación, monitoreo y alertas.
6. **Optimizar la gestión de secretos:** evaluar mecanismos especializados para entornos productivos.
7. **Automatizar la provisión de infraestructura:** incorporar herramientas de infraestructura como código para crear y configurar recursos AWS.

Estas mejoras permitirían evolucionar la solución hacia un proceso más cercano a un entorno productivo.

## 14. Resultado final

Se logró implementar un pipeline de GitLab CI/CD que automatiza la construcción, publicación, análisis de seguridad y despliegue de FinTech Nova en AWS EC2.

La solución mantiene los ocho servicios dockerizados y la arquitectura implementada en la Parte 1.

El pipeline permite identificar las imágenes mediante el commit, generar reportes de seguridad, preparar una instancia EC2 y verificar el funcionamiento de la aplicación mediante HTTPS.

Actualmente, el inicio del job de despliegue es manual para adaptarse a las restricciones temporales de AWS Academy. Sin embargo, el proceso posterior está automatizado y puede configurarse para iniciarse automáticamente modificando las reglas del pipeline.

La prueba realizada confirmó la ejecución de los ocho contenedores, las respuestas HTTPS esperadas y el acceso a la aplicación desde el navegador.

## 15. Documentación complementaria

- [README.md](README.md): documentación de la Parte 1.
- [.gitlab-ci.yml](.gitlab-ci.yml): configuración del pipeline.
- [docker-compose.yml](docker-compose.yml): definición de los servicios.
- [SEGURIDAD.md](SEGURIDAD.md): controles y decisiones de seguridad.
- [ANALISIS.md](ANALISIS.md): análisis de hallazgos.
- [ERRORES.md](ERRORES.md): problemas encontrados y soluciones.
- [AWS_EC2.md](AWS_EC2.md): configuración y despliegue en AWS.
- [DEPLOY.md](DEPLOY.md): procedimiento de despliegue.
- [Enunciado Parte 2](Enunciado-TP-Parte-2.md): requisitos del Trabajo Práctico.