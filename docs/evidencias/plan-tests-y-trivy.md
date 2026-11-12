# Tests de APIs y análisis Trivy

## Tests incorporados

- Clientes (Python): tres pruebas con `unittest` y mocks de base de datos.
- Pagos (Node): dos pruebas HTTP con `node:test`, sin MariaDB.
- Facturas (Java): dos pruebas unitarias del controlador con JUnit/Mockito, sin MariaDB.
- Tarjetas (.NET): smoke test HTTP contra el servicio real iniciado localmente, sin consultar la base de datos.
- Transacciones (Go): prueba unitaria del serializador de respuestas HTTP.

Estos tests son **básicos**: no prueban persistencia ni integración con MariaDB. Ejecutarlos en GitLab y guardar capturas de jobs verdes como evidencia. No afirmar que están validados hasta que el pipeline termine correctamente.

## Trivy

El job `analizar_imagenes_trivy` usa `--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1` y `allow_failure: false`. Los hallazgos HIGH/CRITICAL con corrección disponible hacen fallar el job y bloquean el avance del pipeline al deploy; las vulnerabilidades sin fix se excluyen del reporte/umbral.

Los reportes previos mostraban vulnerabilidades en `tp1-db` y `tp1-api-facturas`. Antes de cambiar imágenes de producción:

1. Reconstruir imágenes con `--pull` (el pipeline ya lo hace) y volver a analizar.
2. Consultar los JSON del nuevo job para confirmar ID de CVE, paquete instalado, versión corregida y disponibilidad.
3. Actualizar la imagen base o aplicar actualizaciones de seguridad en una rama de prueba, según el sistema operativo real de la imagen.
4. Verificar que MariaDB arranca, que Facturas funciona y que Trivy ya no reporta la vulnerabilidad.
5. No desactivar Trivy ni permitir que el job falle para ocultar hallazgos. `--ignore-unfixed` es el filtro acordado para no bloquear por vulnerabilidades todavía no corregibles.

No se modifican las imágenes base automáticamente porque no se verificó una versión corregida y compatible.
