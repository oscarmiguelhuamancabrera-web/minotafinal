# Mi Nota Final Web v1.1.3 - Fix carga de cursos

Versión basada en v1.1.2.

## Cambios principales

- Corrige carga de cursos disponibles en la pantalla del alumno.
- Corrige panel admin Cursos cuando se usan filtros “Todas”.
- Evita consultas anidadas frágiles con `profiles!courses_created_by_fkey`.
- Mantiene filtros Universidad → Facultad → Carrera → Ciclo.
- Muestra mensaje claro si no hay cursos oficiales cargados para el contexto seleccionado.
- Incluye `supabase/migration_v1_1_3_fix_course_loader.sql`.

## Publicación

1. Ejecutar SQL en Supabase.
2. Subir a GitHub.
3. Esperar deploy en Vercel.

```bash
git status
git add .
git commit -m "Version 1.1.3 fix carga de cursos"
git push origin main
```
