# Mi Nota Final — instrucciones para el SQL consolidado

## Qué modifica

`MINOTAFINAL_SUPABASE_PRODUCCION_UNICO.sql` prepara únicamente la base de datos que necesita la versión académica actual:

- protege `public.profiles` contra la elevación de `role` o `status` por un alumno y elimina las políticas históricas permisivas, incluidas las políticas `FOR ALL`;
- conserva el acceso de un administrador activo y limita la lectura/escritura de notas, resultados y cursos al propietario o a un administrador. `admin_emails.status` se crea si no existe (valor inicial `active`) para poder revocar una dirección sin borrar su registro; `is_admin()` solo acepta sesiones con `auth.uid()` y perfiles/correos activos;
- recrea las políticas de `admin_emails` para que solo un administrador activo pueda leer o administrar la lista; no queda acceso `anon`/`public`.
- asegura `student_courses.credits` y `credits_confirmed_at`;
- crea `student_weighted_preferences`, con una fila por usuario y ciclo, confirmación obligatoria al activar, trigger de `updated_at`, índice único y RLS;
- añade `calculation_history.cycle_id` y lo infiere desde el curso cuando es posible;
- valida y mantiene alineados los campos de contexto de `student_courses` con el curso, para impedir reutilizar créditos en otro ciclo. Un único trigger completa el contexto parcial y aplica las restricciones de propiedad/confirmación;
- usa un único trigger para asignar el ciclo de `calculation_history` y una sola FK `calculation_history_cycle_id_fkey` con `ON DELETE RESTRICT`, de modo que eliminar un ciclo con historial asociado se rechace sin perder datos.

No crea ni modifica tablas de temas, buckets, Storage ni decoraciones de Halloween. Halloween funciona con los recursos del frontend.

## Requisitos previos

El proyecto debe tener ya la línea histórica multiuniversidad de Mi Nota Final: `profiles`, `cycles`, `courses`, `student_courses`, `course_grades`, `student_evaluation_scores` y `calculation_history`, con las columnas de contexto que usa la aplicación. El propio script comprueba estas dependencias y aborta antes de modificar si falta una tabla, columna o tipo.

No ejecutes `schema.sql` ni todas las migraciones históricas sobre una base existente para resolver un fallo del preflight. Si aborta, conserva la base intacta, compara el esquema de staging y restaura/aplica la línea histórica correspondiente en un entorno controlado.

## Respaldo y ejecución

1. Crea un proyecto Supabase staging aislado o usa una ventana de mantenimiento autorizada.
2. Haz un respaldo nativo de esquema, datos, políticas RLS, funciones, triggers y Storage. No uses este archivo como sustituto del respaldo.
3. Ejecuta el archivo completo en Supabase SQL Editor. No lo pegues por fragmentos ni lo combines con `migration_v1_1_12_temas_admin.sql`.
4. Si falla el preflight o una restricción, detén la promoción. PostgreSQL revierte la transacción; conserva el mensaje exacto y no reintentes sobre producción sin corregir la incompatibilidad.
5. Si termina, conserva las consultas de solo lectura que aparecen al final del archivo y sus resultados fuera del repositorio si contienen identificadores.

## Comprobaciones posteriores

Las consultas finales deben mostrar:

- `student_courses.credits` y `credits_confirmed_at`;
- `student_weighted_preferences` con su restricción de confirmación y unicidad por usuario/ciclo;
- dos políticas de actualización de perfiles: estudiante protegido y administrador;
- políticas de propietario/administrador en cursos, notas, puntuaciones flexibles, preferencias e historial;
- cero preferencias activas sin `confirmed_at`, cero desajustes de ciclo en `student_courses` y cero desajustes entre historial y curso.

Después, en staging, prueba con JWT reales:

- alumno: intentar cambiar su `role` a `admin` (debe fallar);
- alumno: actualizar un dato permitido de su propio perfil (debe funcionar);
- alumno: leer o modificar notas, resultados o perfiles ajenos (debe fallar o devolver cero filas);
- administrador activo: consultar y gestionar las operaciones administrativas autorizadas.

Una consulta de metadatos ejecutada como propietario no demuestra el aislamiento RLS. Las pruebas JWT deben hacerse con cuentas de prueba de staging.

## Casos de staging que deben ejecutarse antes de promover

Estos casos son una matriz de aceptación. Deben ejecutarse con el cliente de la aplicación o con una conexión que lleve el JWT de cada cuenta de prueba; una consulta del SQL Editor como propietario puede saltarse RLS. Sustituye los marcadores por UUID que existan únicamente en staging y conserva los resultados fuera del repositorio.

1. **Inserción con contexto parcial.** Como alumno, inserta una fila de `student_courses` con `user_id`, `course_id`, `enrollment_type` y `status`, omitiendo `university_id`, `faculty_id`, `career_id` y `cycle_id`. Debe crearse y completar esos cuatro campos con el contexto de `courses`. Repite con un `cycle_id` que no corresponda al curso: debe rechazarse y no debe quedar una fila parcial.
2. **Cambio de ciclo.** Intenta modificar el `cycle_id` de una fila existente a un ciclo distinto al de su `course_id`. Debe rechazarse. Para cambiar de ciclo se debe seleccionar un curso cuyo propio `courses.cycle_id` sea el ciclo destino; en ese caso el contexto resultante debe coincidir en los cuatro campos.
3. **Historial.** Inserta un resultado en `calculation_history` con `course_id` y sin `cycle_id`; el trigger debe guardar el ciclo del curso. Un `cycle_id` explícito diferente, o un ciclo con `course_id` nulo, debe rechazarse. Comprueba que el resto de la fila (notas, promedio y estado) no cambia.
4. **Activación ponderada.** Crea o actualiza la preferencia del alumno para su `current_cycle_id`. Activarla sin `confirmed_at` debe rechazarse. Activarla con confirmación mientras exista un curso visible del ciclo sin `credits_confirmed_at` también debe rechazarse. Tras confirmar los créditos de todos los cursos visibles del ciclo, la activación debe funcionar; una preferencia de otro usuario o de otro ciclo debe rechazarse.
5. **Protección de roles.** Con el JWT de alumno, intenta actualizar `role`, `status`, `id` o `email` de su propio perfil y de otro perfil: cada operación debe fallar o afectar cero filas. Un cambio permitido de datos académicos propios debe funcionar. Con el JWT de administrador activo, las operaciones administrativas autorizadas deben seguir funcionando, y retirar su correo de `admin_emails` debe quitar el acceso cuando no exista un perfil administrativo activo.
6. **Idempotencia.** Ejecuta el archivo completo dos veces en el mismo proyecto de staging. La segunda ejecución debe terminar sin error, sin duplicar filas ni índices, y sin modificar notas, cursos, historiales, perfiles ni preferencias existentes. Compara conteos y una muestra de datos antes y después; confirma también que solo exista un trigger consolidado para `student_courses`, uno para `calculation_history`, una clave foránea `calculation_history_cycle_id_fkey` con `ON DELETE RESTRICT` y una política por nombre.

Si cualquiera de estos casos falla, conserva el error y el estado de staging, no lo corrijas con `DROP`, `TRUNCATE` o borrados manuales, y detén la promoción.

## Ponderado y límite de esta versión

El SQL prepara y protege el promedio ponderado por ciclo. La rama revisada ya lee la preferencia del ciclo, exige créditos confirmados al activarlo y envía `calculation_history.cycle_id`; el trigger de la base también lo deriva cuando el cliente lo omite. El frontend y este SQL deben promoverse como una pareja: si se despliega otra rama que no consuma estas columnas, la interfaz no queda integrada y la promoción debe detenerse.

Los históricos sin `course_id` no pueden recibir un ciclo derivado; permanecen con `cycle_id` nulo y deben excluirse de cualquier resumen que requiera aislamiento por ciclo.

## Recuperación

Si las validaciones staging fallan, no ejecutes correcciones destructivas. Restaura el respaldo nativo de staging o revierte la transacción si el editor aún la mantiene abierta. No uses `DROP TABLE`, `TRUNCATE`, eliminación de cuentas ni borrado de datos académicos como recuperación.

## Verificación realizada

Se revisaron estáticamente `supabase/schema.sql`, las migraciones históricas, las consultas del frontend y las políticas RLS relevantes. No hubo acceso autorizado de solo lectura a Supabase staging/producción y este SQL no se ejecutó en ningún proyecto. No se probó una restauración real ni una prueba JWT remota. La ejecución queda bajo responsabilidad del propietario del proyecto después de validar el esquema y hacer el respaldo.

Antes de ejecutar, confirma que la versión de frontend desplegada corresponde a la rama revisada, que las variables de entorno apuntan al proyecto correcto y que no necesitas activar el gestor de temas en producción.
