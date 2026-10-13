# Auditoría del promedio ponderado de Mi Nota Final

**Fecha:** 13 de octubre de 2026  
**Alcance:** revisión local estática y pruebas aisladas del código disponible. No se modificó código funcional, no se ejecutaron migraciones, no se usaron datos reales, no se hizo commit, push, merge ni despliegue.

## 1. Resumen ejecutivo

El promedio ponderado se calcula en el frontend, en weightedAverageSummary de src/App.jsx:499-523:

P = suma(current_average del curso × créditos del curso) / suma(créditos)

Usa los créditos de student_courses, con valor efectivo 1 cuando faltan, son inválidos o la consulta cae al modo de compatibilidad. Usa el primer historial encontrado para cada curso; la consulta llega ordenada por created_at descendente.

La implementación coincide con el promedio ponderado por créditos cuando cada current_average es una nota final completa. La conclusión es **CORRECTO CON OBSERVACIONES**: el panel puede incluir resultados guardados con evaluaciones pendientes. Además, depende de un historial limitado a 50 filas, no se actualiza al editar una nota hasta guardar un resultado y no filtra explícitamente el historial por periodo académico.

Hallazgos:

- **ALTO H-01:** current_average no está normalizado por el porcentaje evaluado. Un resultado parcial con 60% evaluado y contribución 9.90 entra al promedio como 9.90.
- **MEDIO H-02:** loadHistory limita la consulta a las 50 filas más recientes.
- **MEDIO H-03:** el inicio cambia después de guardar un resultado y recargar historial, no después del autosave.
- **MEDIO H-04:** no hay filtro de periodo en calculation_history.
- **MEDIO H-05:** se agregan valores ya redondeados a dos decimales por curso.
- **BAJO H-06:** créditos faltantes se calculan como 1 sin identificar claramente el valor predeterminado.

## 2. Arquitectura e implementación actual

| Área | Ubicación | Responsabilidad |
|---|---|---|
| Cálculo flexible | src/utils/grades.js:168-246 | Suma notas por porcentaje, identifica pendientes y calcula la nota requerida. |
| Cálculo legacy | src/utils/grades.js:73-151 | PC1-PC4, Parcial y Final con configuración fija. |
| Plantillas | src/App.jsx:1529-1565 | Carga componentes activos por plantilla y los ordena. |
| Cursos | src/App.jsx:1313-1386, loadCourses | Consulta cursos oficiales y visibles del estudiante. |
| Créditos | src/App.jsx:494-497, courseCredits | Convierte créditos; un valor no positivo se convierte en 1. |
| Historial | src/App.jsx:1388-1397, loadHistory | Consulta calculation_history del usuario, cursos activos y máximo 50 filas. |
| Ponderado | src/App.jsx:499-523, weightedAverageSummary | Elige un historial por curso y agrega por créditos. |
| Inicio | src/App.jsx:2989-3070, Dashboard | Muestra promedio, créditos incluidos, pendientes y estado. |
| Autosave | src/App.jsx:1400-1470 | Guarda notas en student_evaluation_scores o course_grades. |
| Resultado | src/App.jsx:1809-1867, handleSaveResult | Inserta una nueva fila en calculation_history. |
| Historial visible | src/App.jsx:3490-3510 | Lista resultados guardados manualmente. |

No se encontró cálculo del ponderado en SQL, RPC o backend: la operación final ocurre en React.

## 3. Flujo de información

loadCourses filtra cursos oficiales por universidad, facultad, carrera y estado activo (src/App.jsx:1320-1327). Después obtiene student_courses con status visible y cursos activos (src/App.jsx:1350-1364), conservando row.credits o 1 (src/App.jsx:1366-1373).

La migración define créditos mayores que 0 y hasta 30 en supabase/migration_v1_0_6_mis_cursos_y_malla_sistemas.sql:61-72. La migración del promedio vuelve a asegurar la columna en supabase/migration_v1_1_10_promedio_ponderado.sql:7-18. Si la columna no existe, el reintento sin credits hace que el frontend use 1.

Las notas se cargan desde student_evaluation_scores con componentes activos; si esa consulta falla, se usa course_grades (src/App.jsx:1553-1617). Las plantillas incluidas son:

- UPSJB: PC1 15%, PC2 15%, PC3 15%, PC4 15%, Parcial 20%, Final 20% (supabase/migration_v1_1_0_multiuniversidad.sql:426-454).
- UAI: 8.33%, 8.33%, 10%, 8.33%, 8.33%, 15%, 8.34%, 8.34% y 25% (supabase/migration_v1_1_0_multiuniversidad.sql:456-487).

calculateFlexibleGradeResult calcula current_average como suma de nota registrada por porcentaje. Las notas vacías quedan pendientes y aumentan pending_weight; no se convierten en cero. La nota requerida es max(0, (mínima - current_average) / (pending_weight / 100)). El resultado se redondea a dos decimales (src/utils/grades.js:232-246). Una nota 0 sí cuenta; se validan valores entre 0 y 20.

Al editar, handleGradeChange actualiza estado, guarda un borrador local y programa autosave remoto de 700 ms (src/App.jsx:1475-1479 y 1459-1470). El autosave no inserta historial. Para que el resultado llegue al inicio se debe usar handleSaveResult.

Al guardar, handleSaveResult inserta snapshot, notas, pesos, current_average, evaluated_weight, pending_weight, pendientes y estado (src/App.jsx:1845-1866). Cada guardado crea una fila nueva.

El inicio obtiene el historial por usuario y cursos activos, ordenado por fecha y limitado a 50 (src/App.jsx:1388-1397). latestHistoryForCourse selecciona el primero cuyo course_id coincide (src/App.jsx:490-492). weightedAverageSummary descarta solo historiales cuyo current_average no sea numérico; no descarta pending_weight.

## 4. Fórmulas matemáticas

Para un curso completo:

nota final = suma(nota × porcentaje / 100)

Para un curso incompleto, el valor guardado sigue siendo la contribución parcial y no se normaliza por el porcentaje evaluado. Por ejemplo, 9.90 con 60% evaluado equivale a 16.50 normalizado sobre lo rendido, pero el panel puede usar 9.90.

El promedio del inicio es:

P_inicio = suma(current_average del historial × créditos) / suma(créditos)

Es correcto para notas finales completas y semánticamente incorrecto para resultados parciales. El resultado por curso se redondea antes de guardarse; luego el panel agrega esos valores redondeados.

## 5. Tratamiento de créditos, notas y pendientes

- Los créditos reales provienen de student_courses.credits.
- Crédito faltante, cero o inválido termina en 1 en courseCredits; la edición normal rechaza cero.
- Un curso desaprobado participa con su nota. Seis notas 8 producen 8.00 y estado Desaprobado.
- Un curso sin historial queda fuera del numerador y denominador.
- Un curso con resultado parcial guardado sí entra; este es H-01.
- Una evaluación pendiente no se interpreta como cero.
- Borrar una nota mediante autosave no borra historiales anteriores; sin guardar un nuevo resultado el inicio conserva el último.
- Generar notas pendientes guarda la nota por autosave, pero no crea historial hasta guardar resultado.
- student_courses tiene unicidad por usuario y curso.
- La agregación entre cursos es igual para cualquier universidad; los porcentajes vienen de la plantilla de cada curso.

## 6. Relación entre calculadora, historial e inicio

ResultCard (src/App.jsx:3461-3487) muestra acumulado, pesos evaluados y pendientes, estado y nota requerida. El inicio muestra promedio y créditos con resultado guardado (src/App.jsx:3017-3021 y 3046-3052) y cada curso con su último current_average y estado (src/App.jsx:3054-3067).

La calculadora se autosincroniza con las tablas de notas, pero history se actualiza solo después de guardar resultado y llamar loadHistory (src/App.jsx:1861-1867). Editar una nota no cambia inmediatamente el ponderado de inicio. HistoryScreen lista resultados guardados manualmente y no recalcula (src/App.jsx:3490-3510).

## 7. Casos de prueba

Las pruebas de curso usaron funciones reales exportadas por src/utils/grades.js y un arnés temporal aislado. Para el ponderado se reprodujo exactamente el cuerpo de weightedAverageSummary porque no está exportada.

### Caso A: siete cursos con diferentes créditos

| Curso | Nota | Créditos | Producto |
|---|---:|---:|---:|
| 1 | 18 | 4 | 72 |
| 2 | 16 | 3 | 48 |
| 3 | 15 | 3 | 45 |
| 4 | 17 | 4 | 68 |
| 5 | 14 | 2 | 28 |
| 6 | 19 | 3 | 57 |
| 7 | 13 | 2 | 26 |
| **Total** |  | **21** | **344** |

Esperado: 344 / 21 = 16.380952..., mostrado como **16.38**. La agregación coincide. Con la plantilla UPSJB y notas de un curso 18, 16, 15, 17, 19 y 13, la función real de curso produjo **16.30**.

### Caso B: cursos pendientes

Sin historial para cursos 5 y 7, los otros cinco producen créditos incluidos 17, puntos 290 y resultado **17.06**. Los cursos ausentes no se tratan como cero ni se proyectan.

Con PC1=18, PC2=16, PC3=15, PC4=17, Parcial vacío y Final vacío, la función real produjo current_average 9.90, evaluated_weight 60, pending_weight 40, required_average 2.75 y estado En proceso. Si se guarda, el panel incluye 9.90 por sus créditos. Esto confirma H-01.

### Caso C: curso desaprobado

Seis evaluaciones en 8 produjeron current_average 8.00, 100% evaluado, 0% pendiente y estado Desaprobado. Al guardar, participa con 8; no se excluye.

### Caso D: modificación

El cambio actualiza estado local, borrador local y autosave remoto. El inicio no cambia porque history no se recalcula. Solo cambia tras guardar resultado y recargar historial. Persistencia de nota verificada; actualización inmediata del ponderado no implementada.

### Caso E: redondeo

Con pesos 33.33%, 33.33% y 33.34%:

- 10.50, 14.50 y 15.50 producen **13.50**.
- 10.495, 14.495 y 15.495 producen **13.50**.
- 10.505, 14.505 y 15.505 producen **13.51**.

El redondeo ocurre en el resultado, no en cada nota. El panel usa luego el resultado de curso ya redondeado.

### Caso F: vacíos e incompletos

- Sin cursos o sin historial: promedio “—”.
- Sin créditos: peso efectivo 1.
- Crédito cero: rechazado por edición; un dato defectuoso cae en 1.
- Resultados de otros periodos: no hay columna de periodo ni filtro por ciclo en calculation_history; un resultado anterior puede reutilizarse si comparte course_id. No se cuantificó sin una base controlada.

### Verificaciones ejecutadas

- node con funciones reales de src/utils/grades.js: completo, parcial, desaprobado, decimales y legacy.
- npm run test:theme: **11 pruebas aprobadas**.
- npm test -- --runInBand: no ejecutable; package.json no define script test.
- npm run build: falló en vite-plugin-pwa con EPERM al resolver index.html en el entorno local; no se atribuye a la matemática.
- No se consultó ni modificó Supabase.

## 8. Hallazgos clasificados

### H-01 — ALTO — resultados parciales incluidos como notas finales

weightedAverageSummary no filtra pending_weight ni normaliza current_average (src/App.jsx:499-523). Un curso con 60% evaluado devuelve 9.90 y, si se guarda, entra multiplicado por sus créditos. Un curso completo 16 con 4 créditos y uno parcial 9.90 con 4 créditos producen (16×4 + 9.90×4) / 8 = 12.95 aunque el segundo no tenga nota final. Impacto: promedio subestimado y mezcla de estados. Recomendación: excluir pending_weight > 0 del promedio definitivo o separar promedio definitivo, acumulado y proyección.

### H-02 — MEDIO — límite global de 50 historiales

loadHistory trae solo las 50 filas más recientes (src/App.jsx:1388-1397). Un curso antiguo puede aparecer sin resultado aunque exista en la base. Se recomienda consultar el último resultado por curso o paginar/agrupar.

### H-03 — MEDIO — el panel no reacciona al autosave

Editar o borrar una nota persiste student_evaluation_scores/course_grades, pero no cambia history (src/App.jsx:1400-1470, 1475-1479 y 1861-1867). La calculadora y el inicio pueden diferir hasta guardar manualmente.

### H-04 — MEDIO — ausencia de periodo académico

calculation_history guarda usuario y curso, pero no ciclo/periodo (supabase/schema.sql:100-117). La carga filtra usuario y curso activo, no contexto (src/App.jsx:1388-1397). Puede reutilizarse un registro de otro periodo.

### H-05 — MEDIO — redondeo por curso antes de agregar

El resultado se redondea a dos decimales antes de guardarse (src/utils/grades.js:232-246) y el ponderado opera sobre ese valor (src/App.jsx:499-523). Pueden aparecer diferencias pequeñas.

### H-06 — BAJO — crédito predeterminado silencioso

Crédito nulo, cero o inválido se convierte en 1 (src/App.jsx:494-497 y fallback 1357-1385). El promedio puede usar un peso inventado sin aviso claro.

## 9. Riesgos funcionales

- La etiqueta promedio ponderado no distingue resultados definitivos de resultados con pendientes.
- Créditos con resultado guardado puede incluir un resultado parcial.
- Guardar varias veces crea historial duplicado; la selección depende de fecha y del límite de 50 filas.
- La ausencia de filtro de periodo deja abierta la mezcla entre ciclos.
- El fallback por migración faltante hace que todos los cursos pesen 1.
- Historial muestra el estado parcial, pero el resumen no lo expone con la misma claridad.
- Las consultas filtran por user_id y existen políticas RLS; no se realizó una prueba de dos cuentas contra Supabase.

## 10. Recomendaciones técnicas

1. Separar promedio definitivo, acumulado y proyección.
2. Incluir en el ponderado definitivo solo resultados con pending_weight = 0 y plantilla válida.
3. Mostrar el avance por separado.
4. Consultar el último resultado por curso sin un límite global que deje cursos fuera.
5. Guardar contexto académico o identificador de periodo en cada resultado.
6. Conservar precisión interna y redondear al presentar.
7. Mostrar cursos incluidos, excluidos por pendientes y crédito usado.
8. Añadir pruebas de cursos completos, parciales, desaprobados, créditos faltantes, duplicados, periodos y cambios.
9. Validar la política académica oficial de cada universidad antes de elegir entre excluir, proyectar o separar cursos pendientes.

## 11. Conclusión general

**Clasificación: CORRECTO CON OBSERVACIONES.**

La fórmula por créditos está correctamente implementada para cursos con nota final completa: suma nota final × créditos y divide entre créditos incluidos. Un desaprobado participa con su nota y las evaluaciones pendientes no se convierten automáticamente en cero dentro de la calculadora.

La evidencia muestra observaciones relevantes: el sistema guarda y agrega current_average aunque haya evaluaciones pendientes; el historial se limita a 50 filas; los cambios no actualizan el ponderado hasta guardar un nuevo resultado; y no hay filtro explícito por periodo. Las recomendaciones quedan documentadas y no fueron implementadas.
