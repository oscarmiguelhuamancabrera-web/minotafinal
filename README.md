# Mi Nota Final Web v1.1.2

Versión de corrección sobre v1.1.1 multiuniversidad.

## Cambios incluidos

- Corrección definitiva de nombres duplicados desde Google.
- Corrección de `full_name` y `name` duplicados en `auth.users.raw_user_meta_data` mediante script SQL.
- Corrección de `first_name`, `last_name` y `full_name` en `public.profiles`.
- Admin/superadmin ve cursos de todas las universidades.
- Panel admin de cursos con filtros: universidad, facultad, carrera y ciclo.
- Reasignación de cursos de Ingeniería de Sistemas UPSJB al contexto correcto:
  - UPSJB
  - Facultad de Ingenierías
  - Ingeniería de Sistemas
  - Ciclo correspondiente
- Sincronización de `student_courses` con el contexto real del curso.
- RLS corregido para catálogos, cursos y `profile_academic_history`.

## Script que debes ejecutar en Supabase

Ejecutar antes de publicar o probar:

```text
supabase/migration_v1_1_2_fix_google_names_admin_courses.sql
```

Ruta:

```text
Supabase → SQL Editor → New query → Run
```

## Publicar

```bash
git status
git add .
git commit -m "Version 1.1.2 fix nombres Google y cursos admin"
git push origin main
```

Si la rama local es `master`:

```bash
git push origin HEAD:main
```

## Variables requeridas en Vercel

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=tu_publishable_key
```

No usar `SUPABASE_SECRET_KEY` en frontend.
