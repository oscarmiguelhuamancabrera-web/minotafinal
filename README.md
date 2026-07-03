# Mi Nota Final Web v1.1.4 - Selector de calculadora por universidad

Versión basada en v1.1.3.

## Cambios principales

- Corrige el error `PGRST201` al cargar cursos con `evaluation_templates`.
- Usa relación explícita: `evaluation_templates!courses_evaluation_template_id_fkey`.
- Agrega selector de plantilla/calculadora en la calculadora.
- El modo invitado permite elegir calculadora por universidad.
- Los porcentajes no están fijos en el frontend: se cargan desde `evaluation_templates` y `evaluation_components`.
- UPSJB y UAI usan sus plantillas configurables activas.
- Mantiene carga de cursos por universidad, facultad, carrera y ciclo.
- Incluye `supabase/migration_v1_1_4_fix_template_selector.sql`.

## Publicación

1. Ejecutar SQL en Supabase.
2. Subir a GitHub.
3. Esperar deploy en Vercel.

```bash
git status
git add .
git commit -m "Version 1.1.4 selector calculadora universidad"
git push origin main
```
