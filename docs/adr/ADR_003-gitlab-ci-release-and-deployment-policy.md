# ADR_003: Pipeline de validación y despliegue automático a main

- **Estado:** Aceptada
- **Fecha:** 2026-11-11
- **Decisores:** Grupo 19

## Contexto

Se requiere validar cambios antes de integrarlos y desplegar automáticamente la aplicación en AWS tras integrar una feature. El entorno de AWS Academy tiene credenciales temporales que deben renovarse por sesión. La configuración de GitLab distingue los pipelines de merge request de los pipelines `push` de una rama.

## Decisión

Organizar CI en los stages `test`, `build`, `security` y `deploy`. Las pruebas, el formato/validación Terraform y los análisis deben finalizar antes de llegar al deploy. El job `validar_origen_mr` se ejecuta en merge requests dirigidos a `main` y acepta únicamente nombres de rama fuente que coincidan con `feat/*`.

Eliminar el job CI legacy `deploy_aws` y conservar solo `deploy_terraform`. Este último se ejecuta automáticamente con `when: on_success` cuando `$CI_COMMIT_BRANCH == "main"` y `$CI_PIPELINE_SOURCE == "push"`. Así, tras mergear una rama `feat/*` a `main`, el pipeline de push a `main` despliega si las etapas previas pasaron.

## Alternativas consideradas

- Deploy manual después de la integración: ofrece una confirmación humana, pero añade un paso operativo y deja despliegues olvidados.
- Deploy durante el pipeline de merge request: ocurriría antes de completar el merge, expondría AWS a cambios aún no integrados y puede tener restricciones de acceso a variables protegidas.
- Filtrar el pipeline de push a `main` por nombre de rama fuente: no es posible con las variables estándar del pipeline push; GitLab presenta la rama actual como `main`, no la rama que fue origen del merge.
- Mantener `deploy_aws` y `deploy_terraform` en paralelo: duplica mecanismos y credenciales y puede confundir destinos/estado.

## Consecuencias

- La regla del job Terraform no puede demostrar que cada push a `main` provino de `feat/*`. También desplegaría cambios integrados desde otra rama o por push directo.
- Para hacer cumplir organizativamente la política, `main` debe estar protegida: `Allowed to push and merge = No one`, merge permitido solo a los roles designados, y los cambios deben entrar mediante merge requests. La configuración del proyecto debe exigir que el pipeline pase antes de mergear.
- La validación de origen en CI aporta un control adicional en MR, pero la protección de rama y permisos son necesarios para impedir vías alternativas.
- AWS Academy debe estar activo y sus variables protegidas actualizadas antes del merge que dispare el deploy. Si faltan credenciales o falla Terraform/deploy, el pipeline queda fallido.
- El despliegue automático reduce pasos manuales, pero aumenta la probabilidad de reemplazar EC2 en cada cambio integrado. Ver ADR_002 sobre la persistencia efímera del disco raíz.

## Referencias

- `.gitlab-ci.yml` (`validar_origen_mr`, `deploy_terraform`)
- `DEPLOY.md`
- `README.md`
- `README_PARTE_2.md`
