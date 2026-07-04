# Mi Nota Final Web v1.2.1

Versión de corrección sobre la línea 1.2 con mejoras de cursos, admin y carga de imagen visible.

## Cambios principales

- Corrección del prellenado de nombres/apellidos de Google en **Completa tu perfil**.
- Modo invitado: ajustes temporales; si recarga la página, vuelve a valores por defecto.
- Alumno registrado: puede cambiar solo porcentajes y nota mínima para su cuenta.
- Alumno no puede cambiar nombres de evaluaciones ni componentes.
- Admin/superadmin: puede editar plantillas globales.
- Calculadora: ya no permite crear cursos nuevos; solo seleccionar cursos existentes.
- Cursos no listados: ahora se solicitan para revisión del administrador.
- Validación de cursos similares para evitar duplicados como “Geo” vs “Geometría Analítica”.
- Registro de quién solicita cursos nuevos.
- Analítica de uso real: cálculo realizado, resultado guardado, curso agregado, ajustes modificados, etc.
- Dashboard admin con métricas de usuarios con uso real y usuarios que solo iniciaron sesión.
- Gráficos del admin con mejor orden, top y agrupación “Otros”.

## SQL requerido

Ejecutar primero en Supabase:

```text
supabase/migration_v1_1_6_mejoras_uso_cursos.sql
```

## Publicación

```bash
git status
git add .
git commit -m "Version 1.2.1 fix boton leer notas desde imagen"
git push origin main
```

Si tu rama local está como `master`:

```bash
git push origin HEAD:main
```


## Cambios v1.2.1

- Botón **Agregar todos los cursos del ciclo** en Mis cursos.
- Admin/Usuarios muestra cursos registrados, cálculos, última conexión, última actividad real e inactividad.
- Filtros de usuarios: sin cursos, sin actividad real, inactivos 7/15/30 días.
- Admin/Cursos carga carreras desde `public.careers`, no solo desde cursos existentes.
- Corrección para evitar que la app regrese sola a Inicio después de refrescos de sesión.
- Calculadora: sección **Leer notas desde imagen** con vista previa y parser de texto reconocido para aplicar notas detectadas.
- Corrección: el bloque **Leer notas desde imagen** ahora se muestra siempre en Calcular; si no hay curso/plantilla, aparece deshabilitado con mensaje de ayuda.
- Se incluyen scripts de sincronización y validación de mallas UPSJB + UAI en `supabase/`.
