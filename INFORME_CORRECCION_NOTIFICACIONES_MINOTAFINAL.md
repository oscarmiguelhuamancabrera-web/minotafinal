# Corrección de notificaciones emergentes

**Fecha:** 13 de octubre de 2026  
**Estado:** corrección local, sin commit, push ni despliegue.

## Problema y causa

El componente de notificaciones se renderizaba con posición fija y top: 18px. El encabezado también ocupa la parte superior de la ventana, por lo que los mensajes podían quedar sobre el menú superior y bloquear sus controles.

Además, el estado solo permitía una notificación visible. Un mensaje nuevo reemplazaba al anterior y el temporizador fijo de 5.5 segundos no distinguía la importancia del mensaje.

## Cambios realizados

- Se creó un contenedor toast-stack con posición fija debajo del encabezado.
- Se añadió separación vertical para varias notificaciones simultáneas.
- Se desactivaron los eventos de puntero en el contenedor y se conservaron únicamente en cada toast.
- Se adaptó la posición y el ancho para pantallas móviles y áreas seguras.
- Las notificaciones ahora se conservan en una cola de hasta cuatro mensajes.
- Duraciones: errores 4.5 segundos, éxitos 3.5 segundos e información 3.2 segundos.
- Se mantuvieron los colores, tipografías y variantes visuales existentes.
- Se añadieron roles alert para errores y status para otros mensajes.

## Archivos modificados

- src/App.jsx: cola de notificaciones, temporizadores y región accesible.
- src/styles.css: posición, separación, ancho responsive, animación y eventos de puntero.

## Validación

- Sintaxis JSX validada con esbuild.
- Se revisaron los puntos de notificación globales mediante búsqueda de notify.
- Se verificó que el stack use pointer-events: none y que cada mensaje sea interactivo solo cuando corresponde.
- Se verificaron reglas desktop y móvil en la hoja de estilos.
- No se modificaron fórmulas, créditos, navegación ni lógica académica.
