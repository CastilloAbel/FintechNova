# ADR_004: GitLab Container Registry y transferencia de imágenes por el runner

- **Estado:** Aceptada
- **Fecha:** 2026-11-11
- **Decisores:** Grupo 19

## Contexto

La Parte 2 requiere publicar las imágenes en el Container Registry del proyecto GitLab. El despliegue corre en una EC2 temporal que no debe conservar credenciales de registry. Además, `deploy.sh` inicia Compose con `--pull never`, por lo que las imágenes deben estar presentes localmente antes de levantar servicios.

## Decisión

Construir y publicar las ocho imágenes en GitLab Container Registry. Etiquetar cada imagen con `CI_COMMIT_SHORT_SHA` para asociarla al commit y publicar además `latest` para usos auxiliares. En el deploy, el runner inicia sesión en el registry, descarga cada imagen, la exporta con `docker save` y la envía por SSH para cargarla en EC2 con `docker load`.

La EC2 no inicia sesión directamente en GitLab Container Registry.

## Alternativas consideradas

- Docker Hub como registry del pipeline: descartado porque la entrega solicita el Container Registry del proyecto GitLab. Se mantiene `scripts/build.sh` como flujo histórico, sin usarlo en el pipeline actual.
- Dar a la EC2 un Deploy Token de lectura: permitiría hacer pull desde EC2, pero almacena/provisiona credenciales adicionales en el host y requeriría modificar el modo actual de `deploy.sh`.
- Cambiar Compose a pull en la instancia: posible, pero necesita disponibilidad de red y autenticación desde EC2; no es el contrato del script actual.

## Consecuencias

- Las credenciales de registry solo se usan en el runner; no se copian al host ni se necesitan en tiempo de ejecución.
- La transferencia consume ancho de banda y tiempo del runner/SSH, y requiere espacio local para descargar las imágenes.
- `CI_COMMIT_SHORT_SHA` ofrece trazabilidad por commit; `latest` es mutable y no debe ser la referencia de despliegues reproducibles.
- La transferencia debe mantenerse sincronizada con los nombres de imagen de Compose y con la lista de ocho servicios.
- Si se migra a pull remoto, revisar primero el manejo de credenciales, permisos mínimos, retención de imágenes y cambios a `deploy.sh`.

## Referencias

- `.gitlab-ci.yml` (`.build_image`, jobs `build_*`, `analizar_imagenes_trivy`)
- `scripts/deploy-ci.sh`
- `scripts/deploy.sh`
- `docker-compose.yml`
- `Enunciado-TP-Parte-2.md`
