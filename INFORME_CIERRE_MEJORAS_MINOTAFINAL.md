# Informe de cierre — mejoras Mi Nota Final

Fecha de revisión: 2026-10-12  
Rama de trabajo: `codex/optimizacion-estabilidad`  
Modalidad: cambios validados y publicados en `origin/main`; sin migraciones ni despliegue manual adicional.

## 1. Resumen ejecutivo

Se implementó una primera entrega integrada sobre la arquitectura React y Supabase existente. La entrega corrige el flujo visual de anuncios, reordena los accesos administrativos, incorpora documentos legales preparados para revisión, exige la aceptación de términos durante el registro y rediseña Cálculos guardados como una vista jerárquica con historial de solo lectura.

## 2. Estado por mejora

| Mejora | Estado |
| --- | --- |
| Activar/inactivar anuncios sin recarga, botón bloqueado y rollback ante error | Implementada y validada por compilación; pendiente de prueba contra Supabase real |
| Accesos administrativos en la parte superior | Implementada y validada por compilación |
| Términos y Condiciones | Redactados para revisión; publicación legal pendiente de confirmación |
| Cláusula de acceso administrativo | Incorporada dentro de Términos y Condiciones |
| Política de Privacidad | Preparada; responsable, proveedores, conservación y canal legal pendientes de confirmar |
| Enlaces legales y aceptación de términos | Implementada en registro, login y pie de autenticación; persistencia de versión pendiente |
| Cálculos agrupados por estudiante/contexto/curso/evaluación | Implementada y validada por compilación |
| Búsqueda y filtros | Implementados por nombre, universidad, carrera, ciclo, curso y estado textual |
| Permisos de consulta | Se conserva el control existente de rol y RLS; pendiente de prueba con roles reales |

## 3. Archivos modificados

- `src/App.jsx`: flujo legal, consentimiento de registro, actualización optimista de anuncios, dashboard administrativo y árbol de cálculos.
- `src/styles.css`: accesos, documentos legales y tarjetas responsive del árbol de cálculos.
- `supabase/propuesta_legal_consentimiento.sql`: propuesta no ejecutada para registrar versiones y fechas de aceptación.
- `INFORME_CIERRE_MEJORAS_MINOTAFINAL.md`: este informe.

## 4. Estructura de Cálculos guardados

La vista agrupa por `user_id`, separa contextos usando universidad, facultad, carrera y ciclo asociados al curso o perfil, agrupa por `course_id`, ordena el historial por `created_at` e identificador estable y muestra el último registro inicialmente. Cada curso permite desplegar evaluaciones registradas, pendientes, peso, aporte, estado, promedio y versiones históricas sin eliminar registros.

## 5. Privacidad y seguridad

No se ampliaron permisos ni se ejecutaron cambios de Supabase. La consulta administrativa continúa dependiendo del rol existente y de las políticas RLS. El texto legal diferencia soporte operativo individual de estadísticas agregadas o anonimizadas. La tabla de consentimiento queda como propuesta hasta definir la estrategia de aceptación de usuarios existentes.

## 6. Validación

- `npm run build`: superado con Vite y generación PWA.
- `npm run test:theme`: 11 pruebas superadas.
- Pruebas pendientes: activar/inactivar contra Supabase, navegación responsive real, cuentas admin/estudiante y verificación RLS, datos históricos con múltiples contextos y registro persistente de consentimiento.

## 7. Riesgos y recomendaciones

La política legal contiene campos marcados como pendientes porque no existe información confirmada sobre razón social, domicilio, proveedores, conservación ni canal de derechos. Confirmar esos datos y aprobar las versiones antes de publicar. Revisar la propuesta SQL en un entorno de prueba, validar RLS y recién después integrar el guardado versionado del consentimiento.

## 8. Git

- Commit de la mejora: `0e7e3f9` (`Implementar mejoras administrativas y legales`).
- Rama de trabajo: `codex/optimizacion-estabilidad`.
- Producción Git: `main` actualizado mediante fast-forward y publicado en `origin/main`.
- Push y merge: realizados; migraciones y despliegue manual: no realizados.
- Estado: árbol limpio salvo `marketing/`, que permanece sin seguimiento y fuera de esta entrega.
