# Mi Nota Final Web/PWA

Aplicación Web/PWA para calcular notas académicas, guardar cursos, registrar historial en Supabase y usarla desde Android, iOS o PC mediante un enlace.

**Versión:** 1.0.0  
**Desarrollado por:** Ing. Oscar Huamán

## Cambios de esta versión

- Diseño responsive optimizado para celular.
- Registro separado por **nombres** y **apellidos**.
- Saludo del dashboard solo con el primer nombre: `Hola, Oscar`.
- Selección de **carrera** y **ciclo académico**.
- Cursos compartidos por **carrera + ciclo**.
- El administrador puede ver quién creó cursos, editar nombres, dar de baja y reactivar.
- Dashboard administrador con reportes gráficos:
  - usuarios que iniciaron sesión hoy,
  - accesos por hora,
  - usuarios por carrera,
  - usuarios por ciclo,
  - distribución por carrera y ciclo.
- Mensaje claro cuando el correo aún no fue confirmado.

## Tecnologías

- React + Vite
- PWA con `vite-plugin-pwa`
- Supabase Auth
- Supabase PostgreSQL
- Vercel compatible

## Importante sobre claves

El proyecto usa solo la clave pública/publicable de Supabase:

```env
VITE_SUPABASE_URL=
VITE_SUPABASE_PUBLISHABLE_KEY=
```

No uses ni subas la `SUPABASE_SECRET_KEY` en este proyecto frontend.

## 1. Actualizar la base de datos en Supabase

Como ya habías ejecutado una versión anterior, usa este archivo:

```text
supabase/migration_v1_0_responsive_admin.sql
```

Ruta:

```text
Supabase → SQL Editor → New query → pegar script → Run
```

Si crearas otro proyecto Supabase desde cero, también puedes ejecutar:

```text
supabase/schema.sql
```

El administrador inicial configurado es:

```text
oscar.miguel.huaman.cabrera@gmail.com
```

Cuando ese correo se registre y confirme, el sistema lo marcará como administrador.

## 2. Ejecutar localmente

Instala Node.js LTS. Luego abre una terminal dentro de la carpeta del proyecto y ejecuta:

```bash
npm install
npm run dev
```

Luego abre:

```text
http://localhost:5173
```

## 3. Variables de entorno

Este ZIP incluye `.env.local` con la URL y la clave pública que compartiste.

Si necesitas cambiarlo, edita:

```text
.env.local
```

Ejemplo:

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=tu_clave_publica
```

## 4. Confirmación de correo

Supabase puede pedir confirmar el correo antes de iniciar sesión. Si el alumno intenta ingresar sin confirmar, la app mostrará:

```text
Tu cuenta aún no está confirmada. Revisa tu correo electrónico para confirmar tu cuenta. También revisa spam o correo no deseado.
```

Para pruebas puedes desactivar la confirmación desde:

```text
Supabase → Authentication → Providers → Email
```

## 5. Configurar login con Google

El botón de Google está listo a nivel de código, pero debes configurar el proveedor en Supabase.

Ruta general:

```text
Supabase → Authentication → Providers → Google
```

Para probar localmente, agrega como URL permitida:

```text
http://localhost:5173
```

Cuando se publique en Vercel, agrega también la URL final, por ejemplo:

```text
https://mi-nota-final.vercel.app
```

## 6. Funciones principales

### Público

- Pantalla de bienvenida
- Registro con nombres, apellidos, carrera y ciclo
- Login con correo y contraseña
- Botón para Google Login
- Recuperar contraseña
- Continuar como invitado

### Invitado

- Calculadora rápida
- Porcentajes editables
- Nota mínima editable
- Guardado local en navegador

### Estudiante

- Dashboard móvil
- Crear cursos por carrera y ciclo
- Ver cursos compartidos de su carrera y ciclo
- Registrar notas por curso
- Calcular promedio actual
- Generar notas mínimas pendientes
- Guardar resultado manualmente
- Ver historial
- Ajustes generales
- Perfil

### Administrador

- Dashboard con reportes gráficos
- Ver usuarios registrados
- Ver quién inició sesión en el día
- Ver accesos por hora
- Ver distribución por carrera y ciclo
- Dar de baja/reactivar usuarios
- Ver cursos creados por usuarios
- Editar nombres de cursos
- Dar de baja/reactivar cursos
- Ver cálculos guardados

## 7. Publicar en Vercel

Cuando esté probado localmente:

```bash
npm run build
```

Luego subes el proyecto a GitHub y conectas el repositorio en Vercel.

También puedes desplegarlo con Vercel CLI si lo tienes instalado.


## Actualización v1.0.1

Antes de probar esta versión, ejecuta también:

```text
supabase/migration_v1_0_1_login_perfil.sql
```

Cambios:

- Mensaje de login más claro cuando el correo no existe o la contraseña es incorrecta.
- Pantalla de completar perfil después de iniciar con Google.
- Permisos RLS para completar perfil si Supabase Auth creó el usuario pero aún no existe el registro en `profiles`.
- Botón visible en el dashboard para cambiar ciclo.
