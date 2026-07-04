-- =========================================================
-- MI NOTA FINAL WEB/PWA
-- MIGRACIÓN 1.0.3: tutorial inicial, cursos seleccionables
-- y reglas para ocultar cursos dados de baja a estudiantes.
-- Pegar en Supabase > SQL Editor > New query > Run
-- =========================================================

-- Marca si el usuario ya vio el tutorial inicial.
alter table public.profiles
  add column if not exists has_seen_tutorial boolean not null default false;

-- Asegura permisos para que el usuario actualice su propio perfil,
-- incluyendo has_seen_tutorial, carrera y ciclo.
drop policy if exists "Usuario actualiza su propio perfil" on public.profiles;
create policy "Usuario actualiza su propio perfil"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Asegura que el usuario pueda crear su propio perfil si inició con Google
-- y el trigger no creó el registro completo.
drop policy if exists "Usuario crea su propio perfil" on public.profiles;
create policy "Usuario crea su propio perfil"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

-- Reafirma la política de cursos: estudiantes solo ven cursos activos
-- de su carrera y ciclo. El administrador ve todo.
drop policy if exists "Cursos visibles por carrera" on public.courses;
create policy "Cursos visibles por carrera y ciclo"
on public.courses
for select
to authenticated
using (
  public.is_admin()
  or (
    status = 'active'
    and career_id in (
      select career_id
      from public.profiles
      where id = auth.uid()
    )
    and cycle_id in (
      select current_cycle_id
      from public.profiles
      where id = auth.uid()
    )
  )
);

-- Política de creación de cursos compartidos por carrera y ciclo del usuario.
drop policy if exists "Usuario crea cursos en su carrera" on public.courses;
drop policy if exists "Usuario crea cursos en su carrera y ciclo" on public.courses;
create policy "Usuario crea cursos en su carrera y ciclo"
on public.courses
for insert
to authenticated
with check (
  public.is_active_user()
  and created_by = auth.uid()
  and career_id in (
    select career_id
    from public.profiles
    where id = auth.uid()
  )
  and cycle_id in (
    select current_cycle_id
    from public.profiles
    where id = auth.uid()
  )
);

-- Nota:
-- Las notas e historial asociados a cursos dados de baja no se eliminan.
-- La app los oculta en la vista del estudiante filtrando cursos activos.
-- El administrador sí puede seguir viéndolos para auditoría/reportes.
