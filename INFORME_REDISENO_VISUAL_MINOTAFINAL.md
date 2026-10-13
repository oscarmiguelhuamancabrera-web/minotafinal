# Informe de rediseño visual — Mi Nota Final

Fecha: 2026-10-13  
Versión anterior: `1.1.8`  
Versión nueva: `1.2.0`  
Rama activa: `main`  
Modalidad: cambios locales, sin commit, push, merge ni despliegue.

## Cambios implementados

- Sistema visual unificado basado en tokens para superficies, texto, bordes, radios, sombras y estados.
- Tema claro con fondos lavanda, tarjetas blancas, morados suaves y acentos secundarios azul, verde y ámbar.
- Tema oscuro con fondos azul noche, superficies moradas diferenciadas, bordes discretos y contraste AA conservado.
- Navegación superior y barra móvil con estados activos, mayor jerarquía y espaciado consistente.
- Dashboard estudiantil con hero renovado, decoración académica CSS, acciones principales, estadísticas de color semántico, resumen y tarjetas de acceso rápido.
- Formularios, botones, tablas, tarjetas, modales, estados vacíos, avisos y controles administrativos con radios, sombras y focus coherentes.
- Diseño responsive revisado para escritorio y móvil, incluyendo navegación inferior y tarjetas compactas.
- Pantalla Acerca de actualizada visualmente y versión sincronizada en `package.json`, `package-lock.json` y la información mostrada por la aplicación.
- Eliminación de pies de página duplicados en tutorial y Acerca de.

## Archivos modificados

- `src/themes.css`
- `src/App.jsx`
- `package.json`
- `package-lock.json`

## Validación observada

Se levantó la aplicación localmente con una configuración temporal de Supabase no sensible para permitir el arranque visual, sin iniciar sesión ni modificar datos.

Pantallas observadas realmente en navegador:

- Login en modo claro, escritorio.
- Login en modo oscuro, escritorio.
- Login en modo oscuro a 390 × 844 px.
- Calculadora invitado en modo oscuro a 390 × 844 px.
- Pantalla Acerca de en modo oscuro a 390 × 844 px, mostrando `Versión: 1.2.0`.

La pantalla autenticada del dashboard no se pudo observar con datos reales porque el entorno local no contiene credenciales Supabase. Sus estilos y estructura fueron revisados en código, pero queda pendiente una captura con una sesión de prueba autorizada.

## Pruebas técnicas

- `npm run build`: superado.
- `npm run test:theme`: 11/11 pruebas superadas.
- `git diff --check`: superado.
- La prueba de contraste oscuro confirmó los tokens AA existentes después de ajustar la nueva paleta.

## Evidencias

Las capturas de las pantallas observadas fueron revisadas durante la sesión de navegador y mostradas inline. El runtime de navegador disponible no expone una ruta de exportación de sus bytes de captura al sistema de archivos, por lo que no se inventaron archivos de evidencia ni se declararon capturas del dashboard autenticado que no pudieron observarse.

## Pendientes

- Revisar dashboard, cursos, calculadora completa, historial y panel administrativo con una cuenta de prueba autorizada.
- Capturar evidencias persistentes de esas pantallas en 360, 390, 430, 768, 1024, 1440 y 1920 px.
- Comparar visualmente cada captura autenticada contra los cuatro prototipos.
- Revisar el warning existente de tamaño de chunk de Vite, sin relación funcional con este rediseño.

## Estado de Git

Cambios locales pendientes en `src/App.jsx`, `src/themes.css`, `package.json` y `package-lock.json`. El directorio no relacionado `marketing/` permanece sin seguimiento y no fue modificado.
