# Observaciones y requerimientos pendientes

## REQ-001 — Solicitudes de cursos visibles para administración

**Estado:** Implementado, pendiente de validación en preview

**Observación:** Un estudiante envía una solicitud para agregar un curso no listado, pero la solicitud no aparece en el perfil administrador.

**Diagnóstico preliminar:** La consulta administrativa de `course_requests` relaciona `profiles` sin indicar cuál clave foránea debe usar. Como la tabla tiene relaciones mediante `requested_by` y `reviewed_by`, Supabase puede rechazar la consulta por ambigüedad. Actualmente el error se reemplaza silenciosamente por una lista vacía.

**Resultado esperado:**

- La solicitud enviada debe persistir en `course_requests`.
- Administradores y superadministradores deben ver todas las solicitudes pendientes.
- La solicitud debe mostrar estudiante, universidad, carrera, ciclo y fecha.
- Los errores al cargar solicitudes no deben presentarse como una lista vacía.

**Validación pendiente:**

- Confirmar en Supabase que la solicitud reportada fue insertada.
- Verificar el error exacto devuelto por la consulta administrativa.
- Probar el flujo completo con perfiles de estudiante y administrador.

## REQ-002 — Separar el ciclo del perfil del filtro de cursos

**Estado:** Implementado, pendiente de validación en preview

**Observación:** Cambiar el ciclo seleccionado en el combo de la sección Cursos no debe eliminar ni modificar los cursos que el estudiante ya agregó.

**Reglas esperadas:**

- Los cursos agregados se mantienen mientras el usuario conserve el mismo ciclo en su perfil.
- Los cursos agregados solo se limpian cuando el usuario cambia oficialmente su ciclo desde su perfil.
- El combo de ciclo dentro de Cursos funciona únicamente como filtro.
- Al cambiar ese combo, solo deben actualizarse las opciones mostradas en el combo/listado de cursos disponibles.
- Cambiar el filtro no debe modificar el ciclo del perfil ni la relación de cursos ya agregados.

**Validación pendiente:**

- Cambiar varias veces el filtro de ciclo y comprobar que “Mis cursos” no se altere.
- Cambiar el ciclo desde el perfil y comprobar que los cursos del ciclo anterior se limpien.
- Confirmar que después del cambio de perfil se carguen únicamente opciones correspondientes al nuevo ciclo.
