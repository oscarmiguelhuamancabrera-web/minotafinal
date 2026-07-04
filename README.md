# Mi Nota Final Web/PWA v1.1.7

Aplicación React + Vite + Supabase + Vercel para cálculo académico de notas.

## Cambios principales v1.1.7

- Botón **Agregar todos los cursos del ciclo** en “Mis cursos”.
- La calculadora solo permite seleccionar cursos existentes; no crea cursos.
- Solicitud de cursos no listados con trazabilidad del usuario.
- Admin: usuarios con cantidad de cursos registrados, cálculos guardados, última conexión, última actividad real e inactividad.
- Admin: filtros para usuarios sin cursos, sin cálculos, sin uso real o inactivos.
- Admin Cursos: carreras cargadas desde `public.careers`, no desde cursos activos.
- Corrección para evitar que la app vuelva sola a Inicio al refrescar sesión/perfil.
- Corrección adicional de nombres duplicados desde Google.
- Se incluyen scripts de sincronización y validación de mallas UPSJB + UAI.

## Supabase

Ejecutar antes de publicar:

```sql
supabase/migration_v1_1_7_admin_cursos_analytics.sql
```

Scripts auxiliares incluidos:

```text
supabase/sync_consolidado_upsjb_uai_courses_fix3_seguro.sql
supabase/validar_comparar_cursos_upsjb_uai.sql
```

## Desarrollo local

```bash
npm install
npm run dev
```

## Publicar

```bash
git status
git add .
git commit -m "Version 1.1.7 admin cursos analytics"
git push origin main
```
