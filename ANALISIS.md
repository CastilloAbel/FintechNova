# Análisis de seguridad

Este informe describe los controles de seguridad ejecutados por el pipeline de FinTech Nova en la rama `ci-seguridad`. Los reportes detallados se generan como artifacts de GitLab y no se versionan en el repositorio.

## Alcance y política

El pipeline analiza el código fuente, los ocho Dockerfiles, los archivos YAML y las ocho imágenes publicadas en el Container Registry de GitLab.

La política adoptada es la siguiente:

- Semgrep bloquea hallazgos de severidad `ERROR`.
- Trivy bloquea vulnerabilidades `HIGH` y `CRITICAL` que tengan una corrección disponible.
- Hadolint bloquea errores de Dockerfile; las sugerencias informativas quedan reportadas.
- Yamllint bloquea errores de formato o sintaxis YAML.
- Gitleaks bloquea secretos detectados en el repositorio.
- Los reportes se publican como artifacts para conservar evidencia de cada ejecución.

## Análisis estático: Semgrep

El job `analizar_codigo_semgrep` ejecuta Semgrep sobre los archivos rastreados por Git. En la ejecución analizada se revisaron 95 archivos con reglas para Python, JavaScript, Java, Go, C#, Dockerfile, YAML y JSON.

Semgrep detectó cuatro incumplimientos de la regla `dockerfile.security.missing-user`, todos relacionados con procesos ejecutándose como `root`:

| Archivo | Hallazgo | Corrección aplicada |
|---|---|---|
| `aplicaciones-contenedores/api-clientes/Dockerfile` | El proceso Python no tenía usuario no root. | Se agregó `appuser`, `appgroup`, `COPY --chown` y `USER appuser`. |
| `aplicaciones-contenedores/api-pagos/Dockerfile` | El proceso Node.js no tenía usuario no root. | Se utilizó el usuario `node` y se asignó la propiedad correspondiente al código. |
| `aplicaciones-contenedores/api-transacciones/Dockerfile` | El binario Go se ejecutaba como `root`. | Se agregó `appuser`, `appgroup`, `COPY --chown` y `USER appuser`. |
| `traefik/Dockerfile` | Traefik se ejecutaba como `root`. | Se declaró el usuario no privilegiado `65532`. |

Estas correcciones reducen los privilegios de los procesos en runtime sin modificar las etapas de compilación ni los puertos de los servicios.

## Vulnerabilidades de imágenes: Trivy

El job `analizar_imagenes_trivy` escanea las ocho imágenes del commit. Se utiliza autenticación contra el Container Registry y se generan ocho reportes JSON como artifacts independientes.

Los JSON que quedaron descargados localmente corresponden a una ejecución anterior a las remediaciones finales: fueron generados el 3 de noviembre de 2026 y analizan las etiquetas `7d91e0d1`. Sirven como línea base, pero no representan las imágenes publicadas por el pipeline final. Esa línea base contenía:

| Imagen | HIGH | CRITICAL | Total |
|---|---:|---:|---:|
| `tp1-traefik` | 0 | 0 | 0 |
| `tp1-db` | 25 | 1 | 26 |
| `tp1-api-clientes` | 0 | 0 | 0 |
| `tp1-api-pagos` | 3 | 0 | 3 |
| `tp1-api-facturas` | 5 | 6 | 11 |
| `tp1-api-tarjetas` | 0 | 0 | 0 |
| `tp1-api-transacciones` | 0 | 0 | 0 |
| `tp1-web` | 4 | 0 | 4 |

La tabla es histórica, no el resultado final. En la ejecución más reciente, posterior a la reconstrucción y publicación de las imágenes corregidas, el pipeline completo terminó correctamente. El job Trivy está configurado para fallar ante vulnerabilidades `HIGH` o `CRITICAL` con corrección disponible (`--ignore-unfixed`); por lo tanto, el resultado verde confirma que no quedaron hallazgos bloqueantes de ese tipo en las imágenes escaneadas. No se asignan conteos exactos de la última ejecución aquí porque sus JSON/artifacts no están descargados en este checkout.

Los hallazgos provienen principalmente de paquetes de las imágenes base y de dependencias de aplicación: Alpine, Red Hat, Ubuntu, Debian, OpenSSL, Go `stdlib`, paquetes Python y Node.js, dependencias Java de Jackson y componentes del runtime .NET.

El job descarga la base de vulnerabilidades de Trivy y, cuando corresponde, la base de Java. Estas bases se utilizan para identificar vulnerabilidades de sistema y de dependencias. El escaneo ignora vulnerabilidades sin versión corregida, pero mantiene el bloqueo para los casos `HIGH` y `CRITICAL` que sí tienen actualización disponible.

El fallo del job ante vulnerabilidades corregibles es intencional: evita que una imagen con problemas conocidos llegue al despliegue. Los casos sin parche disponible no se ocultan; quedan reportados para su evaluación y eventual aceptación formal del riesgo.

Para revisar localmente artifacts descargados, `find-vulnerabilities.ps1` lee los JSON `security/trivy/trivy-report-*.json` y muestra severidad, CVE, paquete, versión instalada y versión corregida. Es una ayuda de lectura: no cambia los reportes ni reemplaza el escaneo automático del pipeline; requiere `jq.exe` disponible en PATH.

### Remediaciones finales y decisiones

Las vulnerabilidades se corrigieron en las entradas que llegan a las imágenes, no ocultando los hallazgos ni relajando la política de Trivy:

- **Clientes:** se actualizaron `PyMySQL` a `1.1.1` y `Werkzeug` a `3.0.3`; se aplican las actualizaciones del sistema Alpine y la API corre como `appuser` sin privilegios de root.
- **Pagos:** se actualizaron la base Node/Alpine y npm; se regeneró el lockfile para recoger parches transitivos. El código se copia con propietario `node` y el servicio corre como ese usuario.
- **Facturas:** el parent de Spring Boot se actualizó a `4.0.9`, que administra versiones corregidas de Spring, Jackson y Tomcat. Se usa el starter `spring-boot-starter-webmvc` correspondiente a esa línea mayor; el runtime continúa con usuario no root.
- **Transacciones:** se elevó Go a `1.26.10` y el módulo a `go 1.26`; también se actualizó Alpine, se aplican parches del sistema y el binario se ejecuta como `appuser`.
- **Base de datos:** se mantiene MariaDB en la línea `11.8`. El reporte de línea base ubicaba la biblioteca estándar vulnerable en el `gosu` que venía dentro de la imagen oficial. Se decidió sustituir ese ejecutable por `gosu` oficial compilado desde el commit `29b939aa5bd4dc588af765b8248f6e39150d2565` con el toolchain actualizado. La primera versión de esta solución falló porque se intentó instalar `github.com/tianon/gosu@v1.19`, etiqueta que no existe con ese formato; se corrigió compilando el código del commit fijado directamente. El cambio no altera los scripts SQL ni la inicialización de MariaDB.
- **Web:** se actualizó Vite a `8.3.5` y la base Alpine; se mantiene `serve` `14.2.6` en dependencias de runtime aisladas del npm global y se fuerza `compression` `1.8.2` mediante override. Se actualizó npm para eliminar el `undici` vulnerable detectado bajo npm. La imagen sigue corriendo como `node`.
- **Tarjetas y Traefik:** los reportes de línea base no mostraron `HIGH`/`CRITICAL` corregibles. Traefik se configuró para correr como UID `65532` como defensa de mínimo privilegio.

Después de una ejecución verde, una nueva base de datos de Trivy reportó `CVE-2026-109518` en `apt` y `libapt-pkg6.0` (`2.6.1`, corregible en `2.6.2`) dentro de Tarjetas. Los dos renglones corresponden al mismo componente APT, no a dos vulnerabilidades distintas. El reporte conserva el mismo `ArtifactID`/`ImageID` de la imagen previamente analizada: la fuente no cambió con la actualización de esta documentación; la base de vulnerabilidades de Trivy ahora reconoce un CVE para el paquete ya presente. Se agregó una actualización selectiva de ambos paquetes en la etapa runtime del Dockerfile, antes de crear el usuario de la aplicación. La corrección debe confirmarse con una nueva construcción y escaneo del pipeline; hasta entonces no se considera validada.

Los cambios se reconstruyeron y analizaron con el pipeline final anterior a este nuevo hallazgo. El resultado exitoso verifica las imágenes del registry asociadas a ese commit, no solo el contenido de los Dockerfiles. Los conteos de reportes anteriores son evidencia histórica; la remediación de APT requiere una nueva ejecución verde antes de afirmar que Tarjetas está nuevamente libre de hallazgos bloqueantes.

## Buenas prácticas de Dockerfiles: Hadolint

El job `analizar_dockerfiles` revisa explícitamente los ocho Dockerfiles del proyecto. Durante la primera ejecución se detectó un error `DL3021` en el Dockerfile de Web, causado por una instrucción `COPY` ambigua. Se corrigió usando un contexto de directorio explícito:

```dockerfile
COPY web/ .
```

El reporte posterior no contiene errores bloqueantes. Conserva avisos informativos sobre usuarios nombrados (`DL3066`) y sobre fijar la versión del paquete `ca-certificates` en Alpine (`DL3018`). Estos avisos no impiden la ejecución porque el pipeline utiliza `--failure-threshold error`; los errores estructurales sí bloquean el job.

## Linting YAML: Yamllint

El job `analizar_archivos_yaml` revisa `.gitlab-ci.yml`, `docker-compose.yml` y la configuración de Traefik.

El reporte local disponible es una línea base anterior a las últimas correcciones y detectaba:

- finales de línea CRLF en lugar de LF;
- ausencia de newline al final de varios archivos;
- espacios sobrantes en `docker-compose.yml`;
- advertencias de longitud de línea en el pipeline;
- espacios adicionales después de dos puntos en la configuración TLS.

Se corrigió el espacio adicional en `keyFile` de `traefik/dynamic/tls.yaml` y se agregó el newline final requerido en `.gitlab-ci.yml`. La regla de longitud se mantiene deshabilitada para no bloquear por comandos CI extensos. El YAML del pipeline solo recibió el ajuste de fin de archivo: no se modificó la lógica de deploy. La ejecución final reportada por el equipo pasó el job Yamllint.

La imagen de Yamllint utiliza un entrypoint vacío en GitLab CI, permitiendo que el runner ejecute el script del job correctamente.

## Detección de secretos: Gitleaks

El job `detectar_secretos` analiza el árbol del repositorio con salida redactada y genera un reporte JSON como artifact. Los archivos `.env`, claves PEM, claves TLS y secretos de Traefik están excluidos mediante `.gitignore`.

La gestión de credenciales se realiza mediante variables protegidas y enmascaradas de GitLab, variables automáticas del Container Registry y Deploy Tokens con permiso restringido para lectura. Las credenciales que hayan sido expuestas deben revocarse y regenerarse; eliminarlas del archivo no invalida una exposición histórica.

## Resultado y decisión

Los controles de Semgrep, Hadolint, Yamllint y Gitleaks integran validaciones automáticas de código, contenedores, configuración y secretos. Trivy analiza las ocho imágenes que se publican en el registry antes de permitir que el pipeline avance al despliegue. El pipeline final fue confirmado como exitoso por el equipo; los hallazgos de la tabla anterior son la línea base previa, no el estado final.

La decisión del equipo es bloquear el flujo ante vulnerabilidades `HIGH` o `CRITICAL` corregibles y ante hallazgos SAST `ERROR`. De esta manera el despliegue manual del job posterior no queda habilitado como resultado de un pipeline que haya omitido controles de seguridad.

Los detalles técnicos de cada ejecución se conservan en los artifacts de GitLab de los jobs `analizar_codigo_semgrep`, `analizar_imagenes_trivy`, `analizar_dockerfiles`, `analizar_archivos_yaml` y `detectar_secretos`. No se suben al repositorio los JSON ni los logs generados por esas ejecuciones.
