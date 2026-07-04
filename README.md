# Mi Nota Final Web/PWA v1.1.8

Aplicación React + Vite + Supabase + Vercel para cálculo académico de notas.

## Cambios principales v1.1.8

- Nuevo **Centro de comunicación**.
- Admin/superadmin puede publicar **Anuncios / Novedades** administrables.
- Los anuncios pueden tener tipo, prioridad, estado, fecha de inicio/fin y destinatarios por universidad, facultad, carrera, ciclo o rol.
- El estudiante puede ver anuncios activos desde Inicio y desde **Avisos y sugerencias**.
- El estudiante puede enviar **Sugerencias / Reportar problema**.
- El admin/superadmin puede responder sugerencias y cambiar estado: pendiente, en revisión, resuelto o rechazado.
- El estudiante puede ver la respuesta del administrador dentro de la app.
- Se excluye admin/superadmin de métricas estudiantiles del dashboard admin.

## Supabase

Ejecutar antes de publicar:

```sql
supabase/migration_v1_1_8_anuncios_sugerencias.sql
```

Si vienes desde una versión anterior, mantener ejecutadas las migraciones previas, especialmente:

```text
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
git commit -m "Version 1.1.8 anuncios sugerencias"
git push origin main
```

## Corrección v1.1.8-fix-modal

- Se agregó el botón **Avisos** en la barra superior de escritorio.
- Se agregó acceso rápido **Avisos y sugerencias** en el panel principal del estudiante.
- Se implementó anuncio tipo **Ventana flotante**.
- La ventana flotante puede mostrar texto o imagen.
- La imagen se carga desde el panel admin y solo se usa para la ventana flotante.
- Se registra el cierre del anuncio por usuario para evitar repetirlo según la frecuencia configurada.

Antes de publicar, vuelve a ejecutar:

```sql
supabase/migration_v1_1_8_anuncios_sugerencias.sql
```


## Fix modal 2

- Corrige la carga de sugerencias para admin/superadmin.
- El panel de comunicación refresca la data administrativa al abrirse.
- Las sugerencias enviadas por alumnos se muestran al superadmin desde Comunicación → Sugerencias.
