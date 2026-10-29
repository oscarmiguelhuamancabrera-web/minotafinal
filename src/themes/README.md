# Motor de temas visuales

`core/themeRegistry.js` es el registro central. Cada tema es un JSON versionado y se valida al iniciar; una configuración inválida se descarta y el tema `original` se conserva como respaldo obligatorio.

`core/themeResolver.js` calcula el tema vigente por fechas inclusivas al inicio y exclusivas al final. Si dos temas coinciden, gana `priority`, después la fecha de inicio más reciente y finalmente el identificador en orden alfabético. `themeEngine.js` agrega el override de previsualización, disponible únicamente en Vite `DEV` y un host local (localhost o IP privada). El panel local también puede simular una fecha y verificar la expiración sin cambiar el reloj del equipo. En producción no se expone ningún panel de previsualización ni acceso de demostración.

Para agregar un tema:

1. Crea `src/themes/<id>/theme.json` siguiendo el contrato de los temas existentes.
2. Importa el JSON en `core/themeRegistry.js` y agrégalo a `validateThemeRegistry([...])`.
3. Añade sus estilos o recursos y conecta el id desde el componente visual correspondiente.
4. Ejecuta `npm run test:theme` y `npm run build`.

El motor solo determina apariencia y recursos. No contiene datos académicos, sesiones ni lógica de Supabase. La futura administración puede consumir el mismo contrato y validar paquetes antes de registrarlos.

El hero reserva una columna derecha (`hero-illustration-slot`) para la ilustración del tema. El contenido académico permanece como HTML en la columna izquierda y el motor solo alterna el recurso visual. El tema original usa `public/themes/original/hero-illustration.svg`; Halloween 2026 conserva `hero-illustration-desktop.webp` y `hero-illustration-mobile.webp`, dos encuadres independientes con degradados oscuros de borde que integran luna, castillo, murciélagos, calabazas, faroles y elementos académicos. Las tarjetas usan iluminación radial discreta y `web-corners.svg` aparece solo como detalle de baja opacidad en encabezado y superficies compatibles; no se usa la captura completa del prototipo como fondo.

Los efectos estacionales se declaran en `theme.json`: Halloween registra tres murciélagos lentos en escritorio, dos en tableta y uno en móvil, además de telarañas con balanceo sutil y soporte de movimiento reducido. `HalloweenHeroBats.jsx` monta la capa dentro del hero para que quede recortada por el contenedor y no cubra el contenido; el login conserva solo una ambientación de fondo tenue. El tema original no monta estas capas y al expirar Halloween se desmontan junto con sus estilos.
