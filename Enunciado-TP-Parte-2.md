# TP 2026 - Parte 2: CI/CD con GitLab, seguridad en el pipeline y Sprint Demo 🚀

## Contexto

En la Parte 1 dockerizaron los microservicios de *FinTech Nova*, los subieron a Docker Hub y los
desplegaron en una instancia EC2 detrás de HTTPS, en gran medida **a mano** o con un script
local.

La Parte 2 consiste en llevar ese trabajo al nivel de un equipo DevOps profesional: **todo el
ciclo (validar, construir, escanear, publicar y desplegar) tiene que ocurrir de forma automática
a través de un pipeline de GitLab**, con controles de seguridad integrados en el proceso y no
como un paso opcional al final.

Además, el cierre del TP es una **Sprint Demo**: van a presentar el resultado como lo harían en
una empresa real, frente a alguien que decide sobre el negocio.

> 🎯 **El destinatario de este trabajo son ustedes mismos.** Es la oportunidad de aprender y de
> ensayar cómo se presenta un avance técnico en una empresa real, con tiempo acotado y ante una
> audiencia que no necesita (**ni quiere**) los detalles de bajo nivel.

---

## Escenario de la presentación: la Sprint Demo

Imaginen la siguiente situación:

- Es la **Sprint Demo** de fin de sprint. Varios equipos tienen que presentar lo que lograron en
  las últimas dos semanas.
- En la reunión está presente el **Jefe de Tecnología (CTO) de FinTech Nova**.
- El tiempo de la reunión es **acotado y compartido**: **cada minuto que su equipo se excede es
  un minuto que le quita a otro equipo.**

Al CTO no le interesa si usaron MariaDB 10.6, 11.4 u 11.8, ni con qué parámetros corrieron un comando. Le interesa:

- **Qué valor entrega** lo que construyeron.
- **Qué están haciendo para evitar que la aplicación se caiga** (downtime) y qué pasa si se cae.
- **Cuánto dinero pierde la empresa** si el servicio no está disponible, y cómo lo están mitigando.
- **Qué riesgos de seguridad** detectaron y cómo los controlan.
- **Qué mejoró** respecto de la entrega anterior.

---

## ⏱️ Definiciones importantes sobre la presentación 🚨

> ⚠️ **Estas reglas forman parte de la evaluación. No son sugerencias.**

### Tiempos

| Bloque | Duración |
|---|---|
| **Exposición del grupo** | **Máximo 10 minutos** |
| Intercambio de feedback (profesor → grupo sobre el TP, y grupo → profesor sobre la materia) | 10 minutos |

---

- 👎🏻 **Cada minuto de exceso en la exposición impacta negativamente en la nota grupal.**
- 🗣️ **Ensayen la presentación cronometrada** antes del día de la demo. Si no la ensayaron, se va a
  notar.

### Qué decir (y qué no)

La pregunta que tienen que hacerse sobre cada cosa que van a decir es:

> **"¿Esto representa algo específico de *nuestro* trabajo, o es teoría que cualquiera podría recitar?"**

Si es teoría, sáquenla.

- ✅ **Sí:**
  - Qué construyeron y qué problema resuelve.
  - Qué decisiones tomaron y **por qué** (en términos de impacto, no de sintaxis).
  - **Qué oportunidades de mejora identificadas en la Parte 1 resolvieron** en esta entrega.
  - **Un solo error interesante** que hayan tenido y cómo lo resolvieron, contado en forma breve.
  - Qué controles de seguridad tiene el pipeline y qué encontraron con ellos.
  - Qué pasa si un servicio falla, y cómo reduce el riesgo su solución.
  - **Presentar una herramienta con su rol en una frase**, para dar contexto: "usamos Traefik como balanceador de carga", "esta herramienta analiza las imágenes en busca de vulnerabilidades".

> 📝 **Aclaración — presentar no es explicar.** Nombrar una herramienta y decir en una frase qué
> rol cumple en *su* solución **está bien y se espera**. Lo que hay que evitar es desarrollar
> el concepto teórico que hay detrás.
>
> | ✅ Presentar (una frase, aporta contexto) | ❌ Explicar (teoría que ya se asume) |
> |---|---|
> | "Usamos Traefik como balanceador de carga delante de las APIs." | "Un balanceador de carga es un componente que distribuye las peticiones entre varias instancias para…" |
> | "Trivy analiza cada imagen antes de publicarla." | "Un CVE es un identificador público de vulnerabilidades que…" |
> | "NGINX es la única puerta de entrada y termina el HTTPS." | "Un reverse proxy recibe las peticiones del cliente y las reenvía a…" |


- ❌ **No:**
  - **Explicar conceptos teóricos** (qué es un contenedor, qué es CI/CD, qué es un pipeline, qué hace un reverse proxy): se asume que los profesores los conocen y que ustedes ya los internalizaron para hacer el TP.
  - **Recorrer uno por uno los errores** de `ERRORES.md`. Elijan el más interesante.
  - **Mencionar modificadores (flags) de comandos ni versiones** de imágenes o herramientas.
  - **Memorizar nombres de APIs externas.** Enfóquense en qué hacen y qué valor aportan (por ejemplo: "convertimos montos a dólares con un servicio externo", no el nombre del proveedor).
  - Entrar en explicaciones técnicas extensas.
  - **Usar lunfardo, jerga o expresiones informales.** Es una reunión profesional.

> 💡 **Mentalidad recomendada:** *"No voy a entrar tan en lo técnico. El CTO está en la reunión."*

### 🪄 Material de apoyo

- **No es obligatorio presentar slides.** Queda a criterio del grupo qué material de apoyo usar (slides, Markdown, el propio repositorio, capturas, el pipeline en GitLab, etc.).
- **Todo el material que usen para presentar debe quedar subido a su repositorio.**
- Igual que en la Parte 1, **cualquier integrante puede ser consultado** durante el feedback: todos deben poder explicar el pipeline y la arquitectura completa, no solo su parte.

---

## 🛠️ Definiciones importantes sobre el TP

El stack a desplegar es **el mismo de la Parte 1** (las 5 APIs, `web`, la DB compartida y, para
grupos de 5 integrantes, `web2`), con los mismos requisitos: HTTPS como única puerta de entrada,
puerto 80 cerrado, secretos fuera del repositorio, límites de recursos, `restart: always`, etc.
**Lo que cambia es cómo se construye, se valida y se despliega.**

### 1. Registry: GitLab del labsys

> 📦 **Las imágenes construidas deben publicarse en el Container Registry de GitLab del labsys** (el del propio proyecto), **no en Docker Hub.**

- El `docker-compose.yml` que corre en la EC2 debe referenciar las imágenes de ese registry.
- Piensen cómo se autentica la EC2 contra el registry para hacer el `pull` sin dejar credenciales personales expuestas (por ejemplo, un *deploy token* con permisos de solo lectura del registry).
- Definan una estrategia de **versionado de imágenes** (tag por commit, por versión, etc.) y documéntenla. Evitar depender únicamente de `latest`.

### 2. Pipeline de GitLab CI/CD

> 🔁 **El despliegue debe hacerse a través de un pipeline de GitLab (`.gitlab-ci.yml`)**, no ejecutando comandos a mano ni corriendo un script desde la máquina de un integrante.

El pipeline debe **aprovechar la funcionalidad vista en clases**, entre otras:

- **Stages** bien definidos (por ejemplo: validación → build → seguridad → publicación → despliegue → verificación).
- **Ejecución en paralelo** de jobs independientes (por ejemplo, build o escaneo de los distintos microservicios al mismo tiempo).
- **Runners** (indicar cuáles usan y por qué).
- **Variables de CI/CD** para secretos y configuración (**enmascaradas** y, donde corresponda, **protegidas**). Ningún secreto en el `.gitlab-ci.yml` ni en el repositorio.
- **Artifacts** (por ejemplo, reportes de los escaneos de seguridad descargables desde el pipeline).
- Cualquier otra funcionalidad que les sume (reglas, `needs`, templates, caché, entornos, jobs manuales para el deploy, etc.).

### 3. Seguridad integrada en el pipeline

> 🛡️ **El pipeline debe incluir herramientas de revisión de seguridad y calidad**, ejecutadas automáticamente en cada corrida.

Como mínimo, debe cubrir estas categorías:

| Categoría | Qué revisa | Ejemplos de herramientas (no obligatorias) |
|---|---|---|
| **Análisis estático de código (SAST)** | Vulnerabilidades en el código fuente | Semgrep, templates de SAST de GitLab, SonarQube |
| **Análisis de vulnerabilidades en imágenes** | CVEs en las imágenes construidas | Trivy, Grype |
| **Buenas prácticas en Dockerfiles** | Usuario no-root, imágenes base, capas, etc. | Hadolint, Checkov |
| **Linting** | Calidad y estilo de código y configuración | Linters de cada lenguaje, `yamllint` |

---

- **No están obligados a usar las herramientas vistas en clase**: pueden proponer otras, siempre que justifiquen la elección.
- Se valora sumar otras categorías (por ejemplo, **detección de secretos** en el repositorio, análisis de infraestructura como código o de dependencias).
- **Definan y justifiquen una política:** ¿qué hace el pipeline si una herramienta encuentra una vulnerabilidad crítica? ¿Corta el despliegue o solo informa? No hay una única respuesta correcta, pero tiene que ser una decisión consciente y documentada.

### 4. Despliegue en AWS (Sandbox de AWS Academy)

> ☁️ **El pipeline debe desplegar la aplicación en una instancia EC2 del Sandbox de AWS Academy.** Es el mismo despliegue de la Parte 1, pero **con mejores prácticas y a través del pipeline.**

- Siguen vigentes las particularidades del sandbox: **sesiones de 2 horas** y, en cada relanzamiento, **instancia, IP pública, Security Group, llaves SSH y credenciales de AWS nuevas.** El pipeline tiene que contemplar esto (por ejemplo, actualizando variables de CI/CD   al inicio de cada sesión) y documentar el procedimiento.
- El despliegue debe dejar la instancia lista de cero (Docker, plugin de Compose, login al registry) y levantar el stack.
- **El pipeline debe verificar que el despliegue funcionó** (por ejemplo, los `curl` por HTTPS a la web y a las 5 APIs de la Parte 1). Un job de deploy "en verde" sin verificación no alcanza.

---

## 📋 Puntos de entrega

Todo debe quedar en el repositorio del grupo, en la rama `main` (o la rama default). **Un proyecto sin su última versión en `main` no será considerado al cargar la nota.**

1. **`.gitlab-ci.yml`** funcional, que construya, escanee, publique y despliegue el stack completo.
2. **Imágenes publicadas** en el Container Registry de GitLab del labsys.
3. **`docker-compose.yml`** actualizado para usar las imágenes del registry de GitLab.
4. **`README.md` del grupo actualizado**, que incluya:
   - **Diagrama del pipeline** (stages, jobs, qué corre en paralelo, dónde intervienen los controles de seguridad) y diagrama de arquitectura actualizado.
   - **Mejoras de la Parte 1 implementadas** en esta entrega (y cuáles quedaron pendientes).
   - **Capturas** de una ejecución exitosa del pipeline y de la aplicación funcionando en AWS, tomadas en una misma sesión del sandbox.
   - Links al registry y al resto de la documentación.
5. **`SEGURIDAD.md` actualizado** con:
   - Herramientas de seguridad elegidas, por qué, y **resumen de los hallazgos** (qué encontraron, qué corrigieron y qué aceptaron como riesgo, justificando).
   - **Política del pipeline ante vulnerabilidades** (corta o informa, y con qué severidad).
   - Gestión de secretos en GitLab (variables enmascaradas/protegidas) y autenticación contra el registry desde la EC2.
6. **`ERRORES.md` actualizado** con los errores nuevos de esta parte (pipeline, runners, registry, credenciales del sandbox, etc.) y cómo los resolvieron.
7. **`AWS_EC2.md` actualizado** con los datos de la última sesión en la que corrió el pipeline completo.
8. **Material de la presentación** (slides, Markdown, etc.) subido al repositorio.

---

## ✅ Criterios de evaluación

- **Pipeline funcional** de punta a punta, evidenciado en GitLab y en las capturas.
- **Uso de las funcionalidades de GitLab CI/CD** (stages, paralelismo, variables, artifacts, runners) con criterio, no por cumplir.
- **Seguridad integrada en el pipeline**: cobertura de las categorías pedidas, análisis de los resultados y política definida.
- **Manejo de secretos**: ninguna credencial en el repositorio ni en el `.gitlab-ci.yml`.
- **Mejoras respecto de la Parte 1** efectivamente implementadas.
- **Documentación** clara y actualizada.
- **Presentación**: claridad, enfoque en el valor del trabajo, lenguaje profesional y **respeto del tiempo máximo de 10 minutos.**

> Hay una nota grupal y una nota individual para evaluar la participación de todos los integrantes.

---

## 🤔 Para pensar / responder

1. ¿Qué ventajas concretas obtiene FinTech Nova al pasar de un `deploy.sh` ejecutado a mano a un pipeline de GitLab? Respondan como si se lo explicaran al CTO.
2. Si el escaneo de imágenes encuentra una vulnerabilidad crítica en una imagen base oficial que todavía no tiene parche, ¿qué decisión toman y por qué?
3. ¿Qué parte del pipeline les ahorra más tiempo gracias a la ejecución en paralelo?
4. Si la aplicación estuviera caída una hora, ¿qué impacto tendría para el negocio? ¿Qué parte de su solución reduce ese riesgo y qué les faltaría para reducirlo más?

---

> Si hay dudas, no duden en contactarnos por los medios establecidos.
