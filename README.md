# Mi Nota Final Web/PWA v1.1.0

Versión de prueba multiuniversidad basada en la v1.0.6 validada.

## Cambios principales

- Registro y perfil con selección dependiente: Universidad → Facultad → Carrera → Ciclo.
- UPSJB queda como universidad base para alumnos existentes.
- El admin/superadmin queda sin universidad asignada por defecto.
- El alumno puede cambiar universidad, facultad, carrera y ciclo desde Perfil.
- Nueva estructura multiuniversidad con UPSJB y Universidad Autónoma de Ica.
- Cursos filtrados por universidad y carrera del estudiante.
- Métodos de evaluación configurables desde el administrador.
- Plantilla UPSJB estándar: PC1, PC2, PC3, PC4, Parcial y Final.
- Plantilla UAI por unidades: FK1, FK2, U1, FK1, FK2, U2, FK1, FK2, U3.
- Calculadora flexible según la plantilla del curso/universidad.
- Login mejorado: Enter en correo pasa a contraseña; Enter en contraseña ejecuta Ingresar.

## Antes de probar

Ejecutar en Supabase:

```text
supabase/migration_v1_1_0_multiuniversidad.sql
```

## Local

```bash
npm install
npm run dev
```

## Producción

Subir a GitHub y esperar deploy en Vercel.

Variables requeridas:

```env
VITE_SUPABASE_URL=...
VITE_SUPABASE_PUBLISHABLE_KEY=...
```

No usar `SUPABASE_SECRET_KEY` en el frontend.
