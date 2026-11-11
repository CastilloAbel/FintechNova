# ADR_001: Traefik como proxy inverso y terminador TLS

- **Estado:** Aceptada
- **Fecha:** 2026-11-11
- **Decisores:** Grupo 19

## Contexto

FinTech Nova expone una interfaz web y cinco APIs. Se necesita un único punto de entrada HTTPS que enrute solicitudes por path, mantenga los puertos de aplicación y de MariaDB en la red privada de Docker y proteja el dashboard de administración.

El material de la consigna utiliza NGINX como ejemplo de puerta de entrada y terminación HTTPS; el equipo eligió Traefik. En el texto consultado, NGINX aparece como referencia ilustrativa para la presentación, no como una restricción técnica explícita. Si la cátedra lo considera una tecnología obligatoria, esta decisión debe revisarse antes de la entrega.

## Decisión

Utilizar Traefik como reverse proxy de entrada y terminador TLS. Publicar únicamente TCP 443 en la instancia. Definir routers por path para la web y las cinco APIs; configurar el dashboard mediante `api@internal` detrás de BasicAuth. Mantener la configuración estática en `traefik/traefik.yml` y las rutas/TLS en `traefik/dynamic/`.

## Alternativas consideradas

- **NGINX:** alternativa sugerida en la consigna. Requiere definir y mantener manualmente la configuración de proxy/rutas y la integración del dashboard no forma parte del mismo componente.
- **Traefik:** seleccionado por integrar routing dinámico, TLS y dashboard en una misma solución Docker, con configuración declarativa versionable.

## Consecuencias

- Existe un punto único de entrada; las APIs y MariaDB no publican puertos al host.
- Las reglas de rutas, prioridades y middlewares viven en archivos versionados y se incorporan a la imagen.
- El dashboard requiere autenticación y devuelve HTTP 401 cuando se consulta sin credenciales.
- La configuración actual monta `/var/run/docker.sock` para el provider Docker. El socket da acceso privilegiado al daemon y representa un riesgo relevante; debe limitarse y evaluarse una API proxy de solo lectura en una evolución futura.
- Para el entorno académico se usa un certificado autofirmado. Cifra el canal, pero los clientes no pueden validar una identidad de servidor confiable sin instalar/emparejar el certificado. En producción debe reemplazarse por un certificado de una CA confiable.
- No se adopta NGINX en esta implementación; documentar esta desviación funcional respecto de la referencia del enunciado.

## Referencias

- `docker-compose.yml`
- `traefik/traefik.yml`
- `traefik/dynamic/`
- `traefik/Dockerfile`
- `Enunciado-TP-Parte-2.md`
