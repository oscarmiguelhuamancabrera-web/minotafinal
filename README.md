# Mi Nota Final Web v1.1.5

Versión: `MiNotaFinalWeb_v1_1_5_logica_calculadora_ajustes`

## Cambios principales

- Calculadora automática según universidad/curso para alumnos registrados.
- Selector de calculadora solo para admin/superadmin e invitado.
- Ajustes con la misma lógica que la calculadora:
  - Alumno: usa la plantilla de su universidad/curso.
  - Admin/superadmin: puede seleccionar plantilla y editar porcentajes globales.
  - Invitado: puede seleccionar plantilla y ajustar porcentajes localmente.
- Porcentajes cargados desde `evaluation_templates` y `evaluation_components`.
- Admin Dashboard: filtros en “Distribución por carrera y ciclo”.
- Mis cursos actuales se filtra por el ciclo seleccionado.
- Incluye carga de malla UAI Medicina Humana de I a XIV ciclo.
- Mantiene fix de relación explícita de `evaluation_templates!courses_evaluation_template_id_fkey`.

## SQL requerido

Ejecutar en Supabase:

```text
supabase/migration_v1_1_5_logica_calculadora_ajustes.sql
```

## Publicación

```bash
git status
git add .
git commit -m "Version 1.1.5 logica calculadora y ajustes por universidad"
git push origin main
```

Si tu rama local está como `master`:

```bash
git push origin HEAD:main
```
