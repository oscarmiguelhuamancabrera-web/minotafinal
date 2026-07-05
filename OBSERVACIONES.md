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

## REQ-003 — Conservar los datos académicos ingresados durante el registro

**Estado:** Implementado en migración, pendiente de aplicar y validar

**Observación:** Después de registrarse e iniciar sesión, el estudiante vuelve a la pantalla “Completa tu perfil” y debe seleccionar nuevamente su universidad.

**Diagnóstico:** El registro envía `university_id`, `faculty_id`, `career_id` y `current_cycle_id` dentro de los metadatos de Auth. Sin embargo, la función `public.handle_new_user()` que crea el registro en `public.profiles` solo copia carrera y ciclo; no guarda universidad ni facultad. Como `isProfileIncomplete()` exige ambos campos, la aplicación muestra nuevamente la pantalla de perfil.

**Resultado esperado:**

- El registro debe guardar universidad, facultad, carrera y ciclo en `public.profiles`.
- Después de confirmar el correo e iniciar sesión, el estudiante no debe volver a ingresar esos datos.
- Los datos académicos deben conservarse también al recargar la aplicación.
- La pantalla “Completa tu perfil” debe mostrarse únicamente cuando realmente falte información.

**Impacto en base de datos:**

- Requiere actualizar la función trigger `public.handle_new_user()` mediante una migración.
- Puede requerir completar perfiles existentes cuyos campos `university_id` o `faculty_id` hayan quedado nulos.

## REQ-004 — Registro sin confirmación por correo

**Estado:** Frontend implementado; pendiente desactivar confirmación en Supabase Auth

**Observación:** Después de crear una cuenta no debe mostrarse ningún mensaje solicitando revisar o confirmar el correo.

**Resultado esperado:**

- Al finalizar el registro, la aplicación debe volver directamente al inicio de sesión normal.
- El usuario debe poder iniciar sesión inmediatamente con el correo y la contraseña registrados.
- No debe mostrarse texto sobre confirmación, spam o correo no deseado.

**Impacto en Supabase:**

- Se debe desactivar la confirmación obligatoria de correo en la configuración de Supabase Auth.
- El frontend debe reemplazar el mensaje actual por una confirmación simple de cuenta creada.
- Quitar únicamente el mensaje no es suficiente: mientras Supabase exija confirmación, el inicio de sesión inmediato será rechazado.

## REQ-005 — Agregar masivamente solo los cursos del ciclo del perfil

**Estado:** Implementado, pendiente de validación en preview

**Observación:** El botón “Agregar todos los cursos del ciclo” no debe usar el ciclo elegido en el combo de filtro.

**Resultado esperado:**

- El combo de ciclo continúa filtrando las opciones para agregar cursos individualmente.
- El botón de agregado masivo usa siempre `current_cycle_id` del perfil del estudiante.
- Cambiar el combo a otro ciclo no cambia el ciclo usado por el agregado masivo.
- El botón queda deshabilitado si el perfil no tiene ciclo o si no existen cursos para su ciclo habilitado.

## REQ-006 — Autocompletar calificaciones desde una imagen

**Estado:** Implementado en rama de desarrollo, pendiente de validar con capturas reales de notas

**Resultado implementado:**

- El estudiante selecciona un curso o plantilla antes de usar el lector.
- Puede cargar una captura o fotografía de hasta 10 MB.
- La imagen se procesa localmente en el navegador con Tesseract.js.
- Se mejora contraste y resolución antes del reconocimiento.
- Las calificaciones detectadas se muestran en campos editables.
- Solo se aplican a la calculadora después de la confirmación del estudiante.
- Se validan valores entre 0 y 20.
- Existe un modo manual para revisar o pegar el texto cuando el OCR no sea suficiente.

**Validación pendiente:**

- Probar con capturas reales de cada universidad soportada.
- Ampliar alias cuando una plataforma use nombres diferentes para las evaluaciones.
- Medir precisión, tiempo de lectura y consumo de memoria en celulares.
