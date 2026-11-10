# Evidencia textual — despliegue Terraform / GitLab CI/CD

Fecha del log: 9 de noviembre de 2026. Versión de las imágenes: `9e4ea77f`.

```text
8 imágenes transferidas a EC2
MariaDB: healthy
Traefik, Web, MariaDB y 5 APIs: Up
OK HTTPS / (HTTP 200)
OK HTTPS /api/clientes (HTTP 200)
OK HTTPS /api/pagos (HTTP 200)
OK HTTPS /api/facturas (HTTP 200)
OK HTTPS /api/transacciones (HTTP 200)
OK HTTPS /api/tarjetas (HTTP 200)
OK HTTPS /dashboard/ (HTTP 401)
Despliegue y verificaciones completados.
Despliegue verificado correctamente.
Aplicacion: https://44.201.197.71/
Dashboard: https://44.201.197.71/dashboard/
Job succeeded
```

El 401 del dashboard es esperado sin credenciales. La IP corresponde a un laboratorio temporal. Este extracto acredita la ejecución de los servicios y las comprobaciones HTTPS, pero no contiene la salida de `terraform apply` ni sustituye las capturas requeridas de la misma sesión.
