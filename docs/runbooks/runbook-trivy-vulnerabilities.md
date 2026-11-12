# Runbook: revisión y remediación de Trivy

## Propósito

Interpretar los resultados del job `analizar_imagenes_trivy`, distinguir hallazgos de imágenes/versiones diferentes y verificar las correcciones en imágenes reconstruidas.

## Política vigente

El job analiza severidades `HIGH,CRITICAL` en las ocho imágenes, usa `--exit-code 1`, no usa `--ignore-unfixed` y tiene `allow_failure: false` (valor predeterminado de GitLab). Cualquier hallazgo HIGH/CRITICAL, incluso sin versión corregida, hace fallar el job y bloquea el avance a `deploy`. Los artifacts se generan también al fallar, para apoyar el diagnóstico. Un pipeline verde solo acredita el resultado del tag/digest y de la base de Trivy de esa ejecución.

En cada pipeline, los jobs reconstruyen las imágenes con `docker build --pull`, y Trivy descarga su base de vulnerabilidades. Por eso un commit que no cambia código de una API igualmente puede producir una imagen distinta o un resultado distinto: pueden cambiar una imagen base mutable, el scanner o su base de CVEs.

## Procedimiento

1. Abrir el pipeline y confirmar commit, `IMAGE_TAG` y estado del job Trivy.
2. Descargar todos los artifacts `trivy-report-*.json` del mismo pipeline. No mezclar reportes de tags, commits o ejecuciones distintas.
3. Revisar la imagen por archivo y distinguir registros por paquete. Un mismo CVE puede aparecer para varios paquetes o imágenes; eso no necesariamente representa CVEs distintos.
4. Colocar los JSON descargados en `security/trivy/` y usar `scripts/find-vulnerabilities.ps1` para obtener un resumen inicial (ver uso abajo).
5. En cada finding registrar al menos: imagen/tag, `VulnerabilityID`, paquete, versión instalada, versión corregida, severidad y `ArtifactID`/digest si está disponible.
6. Confirmar que existe una versión corregida y determinar de qué capa proviene el paquete: imagen base, paquete del sistema o dependencia de aplicación.
7. Corregir la fuente del hallazgo (por ejemplo, actualizar el paquete en la etapa runtime del Dockerfile o la dependencia correspondiente). No editar el JSON, no filtrar el CVE para hacer pasar el gate y no inferir que el README u otro cambio documental causó la vulnerabilidad.
8. Crear un commit que modifique la entrada de build afectada. Ejecutar nuevamente el pipeline y comprobar que el job de build publicó la etiqueta del commit actual.
9. Descargar y revisar el artifact Trivy de esa misma ejecución. Verificar los paquetes/versión corregida y que `ArtifactID`/digest corresponde a la imagen recién construida.
10. Si el mismo CVE aparece con el mismo digest, comprobar si el pipeline realmente reconstruyó y publicó la imagen correcta, si el cache/base image no cambió o si la base de vulnerabilidades de Trivy se actualizó. No permitir el fallo ni ignorar el hallazgo como workaround. Si no existe parche, escalar la investigación; el deploy sigue bloqueado hasta que la política cambie mediante una decisión formal.
11. Registrar la decisión, evidencia y estado en `ANALISIS.md` o en un postmortem si el incidente tuvo impacto operativo.

## Uso del script local

`scripts/find-vulnerabilities.ps1` lee JSON en `security/trivy/trivy-report-*.json` y requiere `jq.exe` en `PATH`. En PowerShell, desde la raíz del repositorio, ejecutar:

```powershell
.\scripts\find-vulnerabilities.ps1
```

El script solo resume findings `HIGH` y `CRITICAL`; no valida el resultado del job, no corrige imágenes y no sustituye la descarga de los artifacts del pipeline investigado. Si la carpeta no existe, créala y coloca allí los JSON descargados, sin cambiar sus nombres.

## Caso observado en este repositorio

Los artifacts locales inspeccionados el 11/11/2026 corresponden a las imágenes etiquetadas `349306ed` y reportan `CVE-2026-109518` en Facturas y DB:

- Facturas: `apt` y `libapt-pkg6.0`, instalados `2.4.14`, corregibles a `2.4.15ubuntu0.1`.
- DB: `apt` y `libapt-pkg6.0t64`, instalados `2.8.3`, corregibles a `2.8.4ubuntu0.1`.

Son cuatro registros de paquete de un mismo CVE en dos imágenes, no cuatro CVEs distintos. La metadata de los reportes señala imágenes construidas entre el 3 y el 6 de noviembre; son evidencia del tag `349306ed`, no una garantía sobre imágenes construidas después. Los Dockerfiles actuales contienen una actualización explícita de los paquetes afectados. Confirmar la corrección con el artifact del mismo pipeline/tag/digest de una nueva construcción. Ver el postmortem [PM-2026-11-trivy-cve-discovery.md](../postmortems/PM-2026-11-trivy-cve-discovery.md).
