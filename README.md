# Mi Nota Final Web v1.1.6

Versión de estabilización y control de uso real.

## Cambios principales

- Corrección del prellenado de nombres/apellidos de Google en **Completa tu perfil**.
- Modo invitado: ajustes temporales; si recarga la página, vuelve a valores por defecto.
- Alumno registrado: puede cambiar solo porcentajes y nota mínima para su cuenta.
- Alumno no puede cambiar nombres de evaluaciones ni componentes.
- Admin/superadmin: puede editar plantillas globales.
- Calculadora: ya no permite crear cursos nuevos; solo seleccionar cursos existentes.
- Cursos no listados: ahora se solicitan para revisión del administrador.
- Validación de cursos similares para evitar duplicados como “Geo” vs “Geometría Analítica”.
- Registro de quién solicita cursos nuevos.
- Analítica de uso real: cálculo realizado, resultado guardado, curso agregado, ajustes modificados, etc.
- Dashboard admin con métricas de usuarios con uso real y usuarios que solo iniciaron sesión.
- Gráficos del admin con mejor orden, top y agrupación “Otros”.

## SQL requerido

Ejecutar primero en Supabase:

```text
supabase/migration_v1_1_6_mejoras_uso_cursos.sql
```

## Publicación

```bash
git status
git add .
git commit -m "Version 1.1.6 mejoras uso real y control cursos"
git push origin main
```

Si tu rama local está como `master`:

```bash
git push origin HEAD:main
```
