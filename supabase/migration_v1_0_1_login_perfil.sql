-- =========================================================
-- MI NOTA FINAL WEB/PWA 1.0.0
-- MIGRACIÓN 1.0.1: perfil después de Google Login,
-- mensajes de login y permisos para completar perfil.
-- Pegar en Supabase > SQL Editor > New query > Run
-- =========================================================

-- Permite que un usuario autenticado cree su propio perfil si
-- el trigger no llegó a crearlo o si inició sesión con Google.
drop policy if exists "Usuario crea su perfil" on public.profiles;
create policy "Usuario crea su perfil"
on public.profiles
for insert
with check (
  id = auth.uid()
  and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  and role = 'student'
  and status = 'active'
);

-- Permite que el correo registrado como administrador cree/complete
-- su perfil con rol admin, incluso si aún no existía en public.profiles.
drop policy if exists "Admin crea perfiles" on public.profiles;
create policy "Admin crea perfiles"
on public.profiles
for insert
with check (public.is_admin());

-- Asegura que el correo administrador exista en la tabla de administradores.
insert into public.admin_emails (email)
values ('oscar.miguel.huaman.cabrera@gmail.com')
on conflict (email) do nothing;

-- Si el usuario administrador ya existe, lo activa y le mantiene carrera/ciclo.
update public.profiles
set
  role = 'admin',
  status = 'active',
  current_cycle_id = coalesce(
    current_cycle_id,
    (select id from public.cycles where order_number = 1 limit 1)
  ),
  career_id = coalesce(
    career_id,
    (select id from public.careers where name = 'Ingeniería de Sistemas' limit 1)
  ),
  updated_at = now()
where lower(email) = 'oscar.miguel.huaman.cabrera@gmail.com';

-- Verificación rápida opcional:
-- select email, role, status, first_name, last_name, career_id, current_cycle_id from public.profiles where lower(email) = 'oscar.miguel.huaman.cabrera@gmail.com';
