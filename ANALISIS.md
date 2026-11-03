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

El resultado inicial de las imágenes mostró la siguiente distribución de vulnerabilidades `HIGH` y `CRITICAL`:

| Imagen | HIGH | CRITICAL | Total |
|---|---:|---:|---:|
| `tp1-traefik` | 0 | 0 | 0 |
| `tp1-db` | 44 | 1 | 45 |
| `tp1-api-clientes` | 26 | 3 | 29 |
| `tp1-api-pagos` | 26 | 1 | 27 |
| `tp1-api-facturas` | 30 | 8 | 38 |
| `tp1-api-tarjetas` | 32 | 1 | 33 |
| `tp1-api-transacciones` | 25 | 1 | 26 |
| `tp1-web` | 52 | 3 | 55 |

Los hallazgos provienen principalmente de paquetes de las imágenes base y de dependencias de aplicación: Alpine, Red Hat, Ubuntu, Debian, OpenSSL, Go `stdlib`, paquetes Python y Node.js, dependencias Java de Jackson y componentes del runtime .NET.

El job descarga la base de vulnerabilidades de Trivy y, cuando corresponde, la base de Java. Estas bases se utilizan para identificar vulnerabilidades de sistema y de dependencias. El escaneo ignora vulnerabilidades sin versión corregida, pero mantiene el bloqueo para los casos `HIGH` y `CRITICAL` que sí tienen actualización disponible.

El fallo del job ante vulnerabilidades corregibles es intencional: evita que una imagen con problemas conocidos llegue al despliegue. Los casos sin parche disponible no se ocultan; quedan reportados para su evaluación y eventual aceptación formal del riesgo.

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
