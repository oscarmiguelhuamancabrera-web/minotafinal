# Informe de modo oscuro — Mi Nota Final

Fecha: 2026-10-12  
Rama: `codex/optimizacion-estabilidad`

## Arquitectura

- `public/theme-init.js` se carga desde `index.html` antes de React. Lee la preferencia local y aplica `data-theme`, `data-theme-preference` y `color-scheme` al documento para evitar destellos del tema incorrecto.
- `src/components/ThemeProvider.jsx` mantiene la preferencia en React y escucha cambios de `localStorage`, del sistema operativo y de otras pestañas.
- `src/themes.css` contiene la paleta oscura y tokens semánticos. `src/styles.css` conserva los valores originales del tema claro como fallback y usa esos tokens en superficies, textos, controles, bordes y estados.
- La preferencia se guarda en `localStorage` con la clave `mnf:appearance`. Las opciones son `auto`, `light` y `dark`; el valor inicial es `auto`.

## Selector y cobertura

El selector **Apariencia** está disponible en la pantalla de bienvenida, autenticación, encabezado del portal y ajustes. Se adapta a escritorio y móvil.

La cobertura CSS alcanza las vistas de acceso, carga, perfil, tutorial, dashboard, cursos, calculadora, OCR, historial, ajustes, comunicación, anuncios flotantes y paneles administrativos. También se adaptaron tablas, tarjetas, formularios, badges, estados, barras de progreso, modales y navegación móvil.

El logotipo oficial se conserva sin recolorarlo; en oscuro permanece sobre una superficie clara para mantener su legibilidad.

## Accesibilidad

- La paleta usa fondo `#0F1020`, superficies `#17182B`/`#202137`, controles `#25263D`, bordes `#373852`, texto `#F5F3FF` y secundario `#B8B6D0`.
- Se mantienen indicadores visibles de foco y se añade un anillo violeta para campos y controles.
- Se respeta `prefers-reduced-motion` en la pantalla de carga existente.
- Los estados de éxito, advertencia, error e información conservan texto y bordes diferenciados, no solo color.

## Archivos modificados

- `index.html`
- `public/theme-init.js`
- `src/main.jsx`
- `src/App.jsx`
- `src/styles.css`
- `src/themes.css`
- `src/components/ThemeProvider.jsx`
- `vite.config.js`
- `package.json`
- `tests/theme.test.mjs`

## Pruebas ejecutadas

- `npm run test:theme`: **7 pruebas correctas**.
  - Preferencia automática antes de React.
  - Persistencia de claro y oscuro.
  - Cambios del sistema en modo automático.
  - Almacenamiento bloqueado o preferencia inválida.
  - Contraste AA de texto, estados, marca y controles.
  - Superficies tokenizadas.
  - Inclusión temprana en PWA y HTML.
- `npm run build`: **correcto**. Vite transformó 124 módulos y generó el Service Worker con `theme-init.js` incluido.
- `git diff --check`: correcto.

## Validación visual pendiente

No se pudieron capturar pantallas interactivas de las rutas autenticadas porque este entorno no tiene credenciales de estudiante/administrador. El servidor local de Vite se inició, pero la inspección del navegador aislado no pudo acceder al socket local y Vite mostró un `EPERM` del entorno al escanear `index.html`. La compilación y las pruebas de tokens sí fueron ejecutadas.

Queda pendiente revisar con cuentas de prueba en un Preview:

1. Modo claro, oscuro y automático en todas las vistas de estudiante.
2. Panel administrativo, tablas y modales con datos reales de prueba.
3. Persistencia después de recargar y reabrir el navegador.
4. Cambio del tema del sistema con la aplicación abierta.
5. PWA instalada en móvil.

No se modificó la base de datos, fórmulas, consultas, permisos ni `main`, y no se realizó ningún despliegue.
