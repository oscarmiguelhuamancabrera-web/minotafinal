# Implementación de créditos y ponderado opcional

**Fecha:** 13 de octubre de 2026  
**Estado:** IMPLEMENTADO CON MIGRACIÓN PENDIENTE

## 1. Resumen ejecutivo

Se implementó el flujo local para que el estudiante active voluntariamente el promedio ponderado por ciclo académico. La calculadora de notas continúa funcionando sin créditos y las fórmulas de evaluación no fueron modificadas.

El Dashboard muestra la opción “¿Quieres ver tu ponderado?”. Al activarla se abre un modal responsive con los cursos visibles del ciclo actual, sus créditos existentes y los cursos que todavía requieren confirmación. El estudiante revisa los valores, pasa a un resumen de confirmación y solo después se guardan los créditos y se habilita la preferencia.

La persistencia de activación requiere la nueva tabla student_weighted_preferences. La migración fue creada, pero no se ejecutó en Supabase ni en producción.

## 2. Causa raíz comprobable

Los créditos se leen desde student_courses.credits. La aplicación tenía dos problemas:

1. La consulta de cursos podía caer a un modo de compatibilidad cuando la columna credits no estaba disponible, dejando el valor efectivo en 1.
2. handleUpdateStudentCourseCredits comparaba el nuevo valor contra courseCredits, que también devuelve 1 para un crédito faltante. Por ello, ingresar 1 en un curso sin valor persistido podía considerarse “sin cambios” y no ejecutar el UPDATE.

La corrección compara contra el valor crudo almacenado mediante storedCourseCredits y carga también updated_at de student_courses. Los créditos no se inventan para habilitar el ponderado: la activación exige confirmar los valores del ciclo.

## 3. Archivos modificados

- src/App.jsx
  - Preferencia de ponderado por usuario y ciclo.
  - Carga filtrada por ciclo para cursos e historial.
  - Modal de configuración y confirmación en dos pasos.
  - Guardado único de créditos con verificación de filas.
  - Activación después de persistir créditos y preferencia.
  - Desactivación visual y nueva confirmación al cambiar de ciclo.
  - Detección de cursos nuevos o créditos modificados después de una confirmación.
  - Comparación correcta de créditos faltantes.
- src/styles.css
  - Tarjeta de activación.
  - Modal responsive, lista de cursos, estados, errores y confirmación.
- src/utils/weighted.js
  - Utilidades puras para créditos persistidos, confirmación por timestamp y agregado ponderado.
- tests/weighted.test.mjs
  - Pruebas de créditos persistidos, cursos sin historial y confirmación por ciclo.
- supabase/migration_v1_2_0_creditos_ponderado_opcional.sql
  - Tabla, índice, trigger y políticas RLS de la preferencia por ciclo.

## 4. Funcionamiento del modal

El primer paso muestra universidad implícita por el contexto del perfil, ciclo actual, cantidad de cursos y cada curso seleccionado. El campo de créditos se precarga cuando existe un valor positivo y queda vacío cuando no existe. También identifica crédito confirmado, pendiente de confirmar o sin registrar.

La validación acepta valores mayores que 0 y menores o iguales a 30, con hasta dos decimales. No permite continuar si falta un curso, existe un valor inválido o no hay cursos seleccionados.

El segundo paso muestra ciclo, cantidad de cursos, créditos totales y la relación exacta de valores que se guardarán. Los botones son Volver y Confirmar y activar. Cancelar o cerrar no persiste cambios.

## 5. Persistencia y seguridad

Confirmar ejecuta un único upsert de todas las filas de student_courses del ciclo. La respuesta debe contener todas las filas enviadas. Si falta una fila o Supabase devuelve error, la preferencia permanece desactivada, el modal conserva los datos y permite reintentar.

Después se hace upsert de student_weighted_preferences con:

- user_id del usuario autenticado.
- cycle_id del perfil actual.
- enabled = true.
- confirmed_at y updated_at de la confirmación.

La tabla tiene unique(user_id, cycle_id). Sus políticas RLS permiten al usuario leer, insertar, actualizar y eliminar únicamente su preferencia; los administradores conservan acceso administrativo.

El contexto del ciclo se mantiene en student_courses.cycle_id y la consulta de cursos se filtra por el ciclo actual. El historial también se filtra por course.cycle_id.

## 6. Ciclos académicos

Al cambiar explícitamente de ciclo:

- se oculta el ponderado actual;
- se limpia la preferencia visible en memoria;
- se ocultan los cursos visibles del ciclo anterior siguiendo el flujo existente;
- se marca el ciclo nuevo para exigir reconfirmación;
- la carga del nuevo ciclo no reutiliza automáticamente una preferencia habilitada previamente.

Al regresar a un ciclo, sus créditos persistidos se precargan, pero la preferencia debe confirmarse nuevamente durante esa sesión de cambio. Una recarga normal o un nuevo inicio de sesión dentro del mismo ciclo conserva la activación confirmada.

## 7. Cursos agregados, retirados y créditos editados

Si el ponderado está activo y se agrega un curso, el nuevo registro tiene updated_at posterior a confirmed_at y el Dashboard abre el modal para confirmar sus créditos. No se incorpora silenciosamente con un peso ficticio.

Al retirar un curso, deja de estar en courses y deja de participar en el ponderado visible; sus notas e historial no se eliminan.

Editar créditos actualiza student_courses. Si el cambio ocurre después de una confirmación, el curso queda pendiente de confirmar y el modal se abre nuevamente. El botón Editar créditos del Dashboard permite iniciar esa revisión manualmente.

El botón Desactivar del Dashboard apaga la preferencia del ciclo sin borrar créditos, notas ni historial. Puede volver a habilitarse mediante el mismo modal.

## 8. Migración de Supabase

Archivo: supabase/migration_v1_2_0_creditos_ponderado_opcional.sql

La migración crea:

- student_weighted_preferences.
- Índice por user_id y cycle_id.
- Trigger de updated_at.
- RLS de lectura, inserción, actualización y eliminación.

Preserva registros existentes y no modifica notas, cursos ni historiales. Debe aplicarse primero en un entorno controlado y verificarse con la consulta incluida al final del archivo. No fue aplicada por esta tarea.

La columna student_courses.credits continúa dependiendo de las migraciones existentes v1_0_6 y v1_1_10. Si esas migraciones no están aplicadas, el guardado real de créditos no puede considerarse operativo; el código conserva la calculadora sin ponderado.

## 9. Pruebas ejecutadas

- node --test tests/theme.test.mjs tests/weighted.test.mjs: 13 pruebas aprobadas.
- Las pruebas nuevas verifican agregado por créditos persistidos, exclusión de cursos sin historial y confirmación basada en confirmed_at.
- Transformación JSX/JS con esbuild: src/App.jsx y src/utils/weighted.js sin errores de sintaxis.
- npm run build: bloqueado por EPERM de vite-plugin-pwa al resolver index.html en este entorno local. No se atribuye a la implementación.
- No se ejecutaron consultas Supabase, migraciones ni pruebas con cuentas reales.

## 10. Limitaciones pendientes

- Falta aplicar y verificar la migración en un proyecto Supabase de prueba.
- La garantía transaccional entre el upsert de student_courses y el upsert de la preferencia depende de dos operaciones consecutivas. Si la segunda falla, los créditos pueden quedar guardados pero el ponderado continúa desactivado; el flujo informa el error y permite reintentar.
- La política académica de excluir o incluir resultados parciales permanece igual, según el alcance solicitado.
- La verificación visual en navegador real queda pendiente porque el build está bloqueado por la restricción EPERM del entorno.

## 11. Estado final

**IMPLEMENTADO CON MIGRACIÓN PENDIENTE.**

El código local permite usar la calculadora sin créditos y habilitar voluntariamente el ponderado por ciclo mediante confirmación explícita. La funcionalidad quedará operativa en Supabase después de aplicar y verificar la migración v1_2_0. No se realizaron commit, push, merge, despliegue ni cambios remotos.
