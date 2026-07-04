-- ============================================================
-- MI NOTA FINAL WEB/PWA v1.1.1
-- FIX PERFIL MULTIUNIVERSIDAD + ADMIN + RLS HISTORIAL
-- Ejecutar después de migration_v1_1_0_multiuniversidad.sql
-- ============================================================

create extension if not exists pgcrypto;

-- 1. Corregir función de validación de plantilla de evaluación
create or replace function public.check_evaluation_template_total_on_active()
returns trigger
language plpgsql
as $$
declare
  total numeric(6,2);
begin
  if new.status = 'active' then
    select round(coalesce(sum(weight_percent), 0)::numeric, 2)
    into total
    from public.evaluation_components
    where template_id = new.id
      and status = 'active';

    if abs(total - 100.00) > 0.01 then
      raise exception 'El método de evaluación debe sumar 100%%. Actualmente suma: %', total;
    end if;
  end if;

  return new;
end;
$$;

-- 2. RLS para permitir que el trigger registre cambios académicos
alter table public.profile_academic_history enable row level security;

drop policy if exists "Usuario ve su historial academico" on public.profile_academic_history;
create policy "Usuario ve su historial academico"
on public.profile_academic_history
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "Usuario o admin registra historial academico" on public.profile_academic_history;
create policy "Usuario o admin registra historial academico"
on public.profile_academic_history
for insert
to authenticated
with check (
  user_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "Admin gestiona historial academico" on public.profile_academic_history;
create policy "Admin gestiona historial academico"
on public.profile_academic_history
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- 3. Asegurar rol superadmin para el correo principal
insert into public.admin_emails (email)
select lower('oscar.miguel.huaman.cabrera@gmail.com')
where exists (
  select 1
  from information_schema.tables
  where table_schema = 'public'
    and table_name = 'admin_emails'
)
and not exists (
  select 1
  from public.admin_emails
  where lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com')
);

-- 4. Si el usuario admin ya existe en auth.users pero no en profiles, crear perfil público
insert into public.profiles (
  id,
  email,
  first_name,
  last_name,
  full_name,
  role,
  status,
  university_id,
  faculty_id,
  career_id,
  current_cycle_id,
  has_seen_tutorial,
  created_at,
  updated_at
)
select
  au.id,
  au.email,
  coalesce(nullif(split_part(coalesce(au.raw_user_meta_data->>'given_name', au.raw_user_meta_data->>'name', 'Administrador'), ' ', 1), ''), 'Administrador'),
  coalesce(au.raw_user_meta_data->>'family_name', ''),
  coalesce(au.raw_user_meta_data->>'name', au.email),
  'superadmin',
  'active',
  null,
  null,
  null,
  null,
  true,
  now(),
  now()
from auth.users au
where lower(au.email) = lower('oscar.miguel.huaman.cabrera@gmail.com')
  and not exists (
    select 1
    from public.profiles p
    where p.id = au.id
  );

-- 5. El admin/superadmin no debe tener universidad/facultad/carrera/ciclo obligatorio
update public.profiles
set
  role = 'superadmin',
  status = 'active',
  university_id = null,
  faculty_id = null,
  career_id = null,
  current_cycle_id = null,
  has_seen_tutorial = true,
  updated_at = now()
where lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com')
   or coalesce(role, '') = 'superadmin';

-- 6. Validación rápida
select
  email,
  role,
  status,
  university_id,
  faculty_id,
  career_id,
  current_cycle_id
from public.profiles
where lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com');
