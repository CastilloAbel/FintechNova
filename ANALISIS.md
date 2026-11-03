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

La última ejecución analizada, anterior a reconstruir nuevamente las imágenes, mostró la siguiente distribución de vulnerabilidades `HIGH` y `CRITICAL`:

| Imagen | HIGH | CRITICAL | Total |
|---|---:|---:|---:|
| `tp1-traefik` | 0 | 0 | 0 |
| `tp1-db` | 25 | 1 | 26 |
| `tp1-api-clientes` | 26 | 3 | 29 |
| `tp1-api-pagos` | 26 | 1 | 27 |
| `tp1-api-facturas` | 30 | 8 | 38 |
| `tp1-api-tarjetas` | 0 | 0 | 0 |
| `tp1-api-transacciones` | 25 | 1 | 26 |
| `tp1-web` | 52 | 3 | 55 |

Los hallazgos provienen principalmente de paquetes de las imágenes base y de dependencias de aplicación: Alpine, Red Hat, Ubuntu, Debian, OpenSSL, Go `stdlib`, paquetes Python y Node.js, dependencias Java de Jackson y componentes del runtime .NET.

El job descarga la base de vulnerabilidades de Trivy y, cuando corresponde, la base de Java. Estas bases se utilizan para identificar vulnerabilidades de sistema y de dependencias. El escaneo ignora vulnerabilidades sin versión corregida, pero mantiene el bloqueo para los casos `HIGH` y `CRITICAL` que sí tienen actualización disponible.

El fallo del job ante vulnerabilidades corregibles es intencional: evita que una imagen con problemas conocidos llegue al despliegue. Los casos sin parche disponible no se ocultan; quedan reportados para su evaluación y eventual aceptación formal del riesgo.

### Remediación aplicada

Se actualizaron los orígenes y dependencias que correspondían a los hallazgos:

- Alpine se actualizó a la línea `3.22` en las imágenes de Pagos, Transacciones y Web, y las capas Alpine ejecutan `apk upgrade` durante la construcción.
- El runtime de Go pasó de 1.22 a 1.25 y el módulo fue actualizado a `go 1.25`.
- Spring Boot pasó de 3.3.4 a 3.3.11, incorporando versiones corregidas de Spring, Jackson y Tomcat administradas por el parent.
- Pagos regeneró su `package-lock.json`; su auditoría npm quedó sin vulnerabilidades.
- Web pasó de Vite 5 a Vite 8.3.5 y `serve` se actualizó a 14.2.6. La auditoría de dependencias de producción quedó sin vulnerabilidades y el build se verificó con Vite 8.3.5.
- Clientes actualizó PyMySQL a 1.1.1 y Werkzeug a 3.0.3.
- MariaDB pasó de la etiqueta de parche fija a la línea 11.8 para recibir las actualizaciones de seguridad de la imagen oficial.
- En una segunda ejecución, Clientes, Tarjetas y Traefik quedaron sin hallazgos `HIGH` o `CRITICAL`. Los resultados restantes se redujeron en Web, Pagos y Transacciones después de actualizar bases y dependencias.
- Facturas todavía requiere validar el salto a Spring Boot 3.5.14, que incorpora versiones corregidas de Spring, Jackson y Tomcat.
- El hallazgo restante de MariaDB aparece en `/usr/local/bin/gosu`, un binario auxiliar provisto por la imagen oficial. No corresponde al código de FinTech Nova ni puede corregirse desde los scripts SQL; depende de una nueva versión de la imagen que actualice ese binario.

La remediación se verificó localmente para Web, Pagos, Go y Python. La confirmación definitiva requiere reconstruir y publicar las ocho imágenes, ya que Trivy analiza las imágenes del registry y no los Dockerfiles directamente. Si MariaDB continúa reportando `gosu` sin una imagen upstream corregida, el equipo debe registrar esa limitación como riesgo aceptado y justificarla explícitamente.

## Buenas prácticas de Dockerfiles: Hadolint

El job `analizar_dockerfiles` revisa explícitamente los ocho Dockerfiles del proyecto. Durante la primera ejecución se detectó un error `DL3021` en el Dockerfile de Web, causado por una instrucción `COPY` ambigua. Se corrigió usando un contexto de directorio explícito:

```dockerfile
COPY web/ .
```

El reporte posterior no contiene errores bloqueantes. Conserva avisos informativos sobre usuarios nombrados (`DL3066`) y sobre fijar la versión del paquete `ca-certificates` en Alpine (`DL3018`). Estos avisos no impiden la ejecución porque el pipeline utiliza `--failure-threshold error`; los errores estructurales sí bloquean el job.

## Linting YAML: Yamllint

El job `analizar_archivos_yaml` revisa `.gitlab-ci.yml`, `docker-compose.yml` y la configuración de Traefik.

El primer reporte detectó problemas de formato del repositorio:

- finales de línea CRLF en lugar de LF;
- ausencia de newline al final de varios archivos;
- espacios sobrantes en `docker-compose.yml`;
- advertencias de longitud de línea en el pipeline;
- espacios adicionales después de dos puntos en la configuración TLS.

Se normalizaron los finales de línea, se eliminaron espacios sobrantes y se garantizó el newline final. La regla de longitud se mantiene informativa para no bloquear el pipeline por comandos CI extensos que siguen siendo legibles y funcionales.

La imagen de Yamllint utiliza un entrypoint vacío en GitLab CI, permitiendo que el runner ejecute el script del job correctamente.

## Detección de secretos: Gitleaks

El job `detectar_secretos` analiza el árbol del repositorio con salida redactada y genera un reporte JSON como artifact. Los archivos `.env`, claves PEM, claves TLS y secretos de Traefik están excluidos mediante `.gitignore`.

La gestión de credenciales se realiza mediante variables protegidas y enmascaradas de GitLab, variables automáticas del Container Registry y Deploy Tokens con permiso restringido para lectura. Las credenciales que hayan sido expuestas deben revocarse y regenerarse; eliminarlas del archivo no invalida una exposición histórica.

## Resultado y decisión

Los controles de Semgrep, Hadolint, Yamllint y Gitleaks integran validaciones automáticas de código, contenedores, configuración y secretos. Trivy agrega el análisis de vulnerabilidades de las imágenes antes del despliegue.

La decisión del equipo es bloquear el flujo ante vulnerabilidades `HIGH` o `CRITICAL` corregibles y ante hallazgos SAST `ERROR`. De esta manera el despliegue manual del job posterior no queda habilitado como resultado de un pipeline que haya omitido controles de seguridad.

Los detalles técnicos de cada ejecución se conservan en los artifacts de GitLab de los jobs `analizar_codigo_semgrep`, `analizar_imagenes_trivy`, `analizar_dockerfiles`, `analizar_archivos_yaml` y `detectar_secretos`. No se suben al repositorio los JSON ni los logs generados por esas ejecuciones.
