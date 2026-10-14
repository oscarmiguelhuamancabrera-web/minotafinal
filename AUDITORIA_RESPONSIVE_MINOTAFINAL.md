# Auditoría responsive de Mi Nota Final

**Fecha:** 13 de octubre de 2026  
**Rama revisada:** main  
**Alcance:** inspección estática de JSX/CSS y validación local de compilación y pruebas.

## 1. Resumen general

La aplicación ya cuenta con breakpoints principales en 820, 720, 560 y 430 px. La navegación móvil, los modales de configuración, el anuncio flotante y el modal de cálculos administrativos ya disponían de scroll interno. La revisión encontró riesgos en tamaños intermedios: el acceso administrativo conservaba cinco columnas hasta 720 px, formularios de tres columnas podían permanecer demasiado comprimidos en tablets y algunos resúmenes administrativos tenían cuatro columnas antes de llegar al breakpoint móvil.

Se corrigieron esos casos con reglas compartidas para 1024, 900, 820 y 560 px. También se reforzó el confinamiento del scroll horizontal y vertical para que las tablas y modales no desplacen la página completa.

## 2. Pantallas y componentes revisados

### Acceso y autenticación

Se revisaron Splash, Login, Register, AuthCard, CompleteProfile, términos y privacidad. Los formularios usan grids de uno o dos campos y el breakpoint de 820 px los convierte en una columna. No se cambió la lógica de autenticación.

### Panel del estudiante

Se revisaron Dashboard, cursos, calculadora, lector OCR, historial, configuración, perfil, avisos, sugerencias, modal de créditos y anuncios flotantes. Los grids de evaluación, formularios y tarjetas tienen adaptación móvil. El modal de créditos y el anuncio flotante cuentan con ancho limitado, altura máxima y desplazamiento interno.

### Panel administrativo y superadministrador

Se revisaron Dashboard administrativo, accesos, estadísticas, gráficos, filtros, usuarios, cursos, cálculos, métodos de evaluación, comunicación, anuncios, sugerencias y modales de detalle. Las tablas pasan por ResponsiveTable, que mantiene el desplazamiento dentro de su propio contenedor.

## 3. Matriz de resoluciones y roles

| Resolución | Cobertura CSS | Riesgo revisado |
|---|---|---|
| 320 × 568 | reglas de 560 y 430 px | botones, navegación inferior, modales y ancho del contenido |
| 360 × 800 | reglas de 560 y 430 px | formularios, tarjetas y mensajes largos |
| 390 × 844 | reglas de 560 y 430 px | modal de créditos y anuncios |
| 430 × 932 | regla de 430 px | grids de evaluación y estadísticas |
| 768 × 1024 | reglas de 900 y 820 px | administración en tablet vertical |
| 1024 × 768 | regla de 1024 px | acceso administrativo y grids de tres campos |
| 1280 × 800 | reglas base | navegación de escritorio y tarjetas |
| 1440 × 900 | reglas base | distribución amplia |
| 1920 × 1080 | max-width del contenedor | no estirar contenido sin control |

No se dispuso de credenciales de prueba para recorrer cada rol en un navegador real. La validación de navegador local fue bloqueada por la revisión automática de seguridad al abrir localhost; no se presentó como una captura visual aprobada.

## 4. Hallazgos

### R-01 — MEDIO — acceso administrativo comprimido en tablets

En src/styles.css el admin-access-grid tenía cinco columnas por defecto y solo pasaba a dos columnas en 720 px. En tablets de 768 a 1024 px los botones podían quedar estrechos y sus textos podían crecer la fila de forma irregular.

**Corrección:** tres columnas hasta 1024 px, dos hasta 900 px y una columna en pantallas pequeñas.

### R-02 — MEDIO — grids administrativos de tres campos

Los formularios con grid.three podían mantener tres campos hasta 820 px. En tablets y ventanas intermedias los controles quedaban comprimidos, sobre todo en comunicación y evaluaciones.

**Corrección:** dos columnas hasta 1024 px y una columna desde 820 px.

### R-03 — MEDIO — resúmenes administrativos con demasiadas columnas

Los resúmenes de estudiantes, cursos y cálculos podían mantener varias columnas en anchos intermedios.

**Corrección:** dos columnas hasta 1024 px, una columna hasta 900 px, conservando toda la información y las acciones.

### R-04 — BAJO — scroll horizontal no confinado explícitamente

ResponsiveTable ya tenía overflow, pero no declaraba límites ni comportamiento táctil de desplazamiento horizontal.

**Corrección:** max-width, overscroll-behavior-x y desplazamiento inercial dentro del contenedor.

### R-05 — BAJO — contenedores flexibles con min-width implícito

Varios grids y tarjetas no establecían min-width: 0, lo que puede impedir que los hijos reduzcan su tamaño cuando contienen textos largos.

**Corrección:** min-width: 0 en layouts y tarjetas compartidos, además de overflow-wrap para contenidos largos.

## 5. Componentes verificados sin cambios funcionales

- Navegación de escritorio y móvil.
- Toast stack y notificaciones.
- Modal de configuración de créditos.
- Anuncio flotante de texto e imagen.
- Modal de cálculos administrativos.
- Tablas administrativas y sus acciones.
- Gráficos y tarjetas de estadísticas.
- Formularios de autenticación y perfil.
- Modo claro y oscuro mediante las variables visuales existentes.

## 6. Hallazgos pendientes

La verificación visual con usuarios autenticados por rol queda pendiente porque no hay credenciales de prueba disponibles y el navegador local fue bloqueado por la revisión automática de seguridad. No se identificó un bloqueo funcional adicional en la inspección estática.

## 7. Estado

Los hallazgos responsive reproducibles en CSS fueron corregidos localmente. No se realizaron cambios de lógica de negocio, fórmulas, roles, permisos, consultas ni datos.
