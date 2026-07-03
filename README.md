# Mi Nota Final Web/PWA

Aplicación Web/PWA para calcular notas académicas, guardar cursos, registrar historial en Supabase y usarla desde Android, iOS o PC mediante un enlace.

**Versión:** 1.0.6

## Cambios principales v1.0.6

- Corrección de nombres y apellidos cuando el usuario inicia con Google.
  - Ejemplo: `OSCAR MIGUEL HUAMAN CABRERA` se separa como `OSCAR MIGUEL` y `HUAMAN CABRERA`.
- La ventana de inicio del alumno ahora muestra un resumen académico de sus notas por curso.
- El alumno puede entrar a la calculadora desde:
  - botón general **Calcular**,
  - botón **Calcular** de cada curso.
- Se agrega la lógica de **Mis cursos actuales**.
- El alumno puede llevar cursos de diferentes ciclos:
  - regular,
  - arrastrado,
  - adelantado,
  - electivo,
  - otro.
- El alumno puede ocultar cursos que no lleva para no cargar su página principal.
- El administrador ve los estados en español: **Activo** / **Inactivo**.
- Los cursos precargados por script se muestran como creados por **Sistema**.
- Las listas largas del administrador tienen scroll interno.
- Se agrega script SQL para cargar la malla curricular de Ingeniería de Sistemas por ciclos.
- Se agrega reporte de cursos por tipo de matrícula en el dashboard administrador.

## Tecnologías

- React + Vite
- PWA con `vite-plugin-pwa`
- Supabase Auth
- Supabase PostgreSQL
- Vercel compatible

## Variables de entorno

Crear `.env.local` usando el modelo de `.env.example`:

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=tu_clave_publica
```

No uses ni subas la `SUPABASE_SECRET_KEY` en este proyecto frontend.

## Actualizar base de datos

Para usar esta versión, ejecuta en Supabase:

```text
supabase/migration_v1_0_6_mis_cursos_y_malla_sistemas.sql
```

Ruta:

```text
Supabase → SQL Editor → New query → pegar script → Run
```

Este script:

- crea la tabla `student_courses`,
- actualiza las políticas RLS,
- permite cursos de diferentes ciclos,
- carga los cursos de Ingeniería de Sistemas por ciclo,
- deja `created_by = null` para cursos de carga inicial, que la app mostrará como **Sistema**.

## Ejecutar localmente

```bash
npm install
npm run dev
```

Abrir:

```text
http://localhost:5173
```

## Publicar en Vercel

```bash
npm run build
git add .
git commit -m "Versión 1.0.6"
git push
```

Vercel desplegará automáticamente si el repositorio está conectado.

## Funciones principales

### Estudiante

- Registro con nombres, apellidos, carrera y ciclo.
- Login con correo/contraseña.
- Login con Google.
- Modo invitado.
- Dashboard con resumen de notas.
- Gestión de **Mis cursos actuales**.
- Agregar cursos regulares, arrastrados, adelantados, electivos u otros.
- Ocultar cursos que no lleva.
- Calcular nota por curso.
- Guardar resultado manualmente.
- Ver historial.
- Cambiar ciclo desde perfil.

### Administrador

- Dashboard con reportes.
- Usuarios registrados.
- Usuarios conectados hoy.
- Accesos por hora.
- Usuarios por carrera y ciclo.
- Cursos por tipo de matrícula.
- Gestión de usuarios.
- Gestión de cursos.
- Cursos creados por alumnos, admin o Sistema.
- Estados visibles en español.
- Listas largas con scroll interno.
