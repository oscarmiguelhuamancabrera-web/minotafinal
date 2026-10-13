# Informe de actualización automática — Mi Nota Final

Fecha: 2026-10-12  
Rama: `codex/optimizacion-estabilidad`

## Sistema implementado

- Vite genera `dist/version.json` en cada compilación.
- El identificador usa `VERCEL_GIT_COMMIT_SHA` en Vercel, `VITE_BUILD_ID` cuando se proporciona y un identificador local solo para builds locales.
- La versión mostrada en Acerca usa el identificador real de la compilación cargada.
- `src/pwaUpdates.js` registra el Service Worker con `virtual:pwa-register`, revisa `version.json` sin caché y solicita la actualización al SW cuando aparece una versión nueva.

## Cuándo se verifica

- Al registrarse el Service Worker.
- Al iniciar la aplicación.
- Al volver al foco o desde segundo plano.
- Al recuperar conexión.
- Cada 15 minutos mientras la aplicación permanece abierta.

Las comprobaciones se deduplican. Se guarda un intento por build en `sessionStorage` para impedir ciclos infinitos.

## Protección de datos

Antes de actualizar, la aplicación consulta el guardia global de operaciones críticas. Si hay una sincronización de calificaciones pendiente o un guardado en curso, conserva la versión actual y muestra un aviso para reintentar más adelante.

No se borra `localStorage`, `sessionStorage`, IndexedDB, la sesión ni los borradores de calificaciones.

## Caché y entornos

- `version.json` no se precachea y usa `NetworkOnly` en Workbox.
- Vercel entrega `version.json` sin caché y `index.html` con revalidación.
- JavaScript y CSS mantienen nombres con hash y la estrategia precache existente.
- La URL se resuelve contra el origen actual; Preview y producción no se comparan entre sí.

## Pruebas realizadas

- `npm run test:theme`: 10 pruebas correctas, incluidas las reglas del manifest, `version.json`, caché y guardas de actualización.
- `npm run build`: correcto; se generó `dist/version.json` y el Service Worker dejó `version.json` fuera del precache.
- `git diff --check`: correcto.

## Pendientes de despliegue

No se pudo ejecutar en este entorno una actualización real entre dos despliegues ni validar PWA instalada en Android/iOS, varias pestañas o cuentas autenticadas. Esas pruebas requieren un Preview desplegado y dispositivos/sesiones de prueba.

No se hizo `git push`, no se fusionó `main` y no se desplegó producción.
