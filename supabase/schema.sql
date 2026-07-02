-- =========================================================
-- MI NOTA FINAL WEB/PWA 1.0.0
-- SCHEMA COMPLETO + MIGRACIÓN IDÉNTICA
-- Sirve para proyectos nuevos y para actualizar la versión anterior.
-- Pegar en Supabase > SQL Editor > New query > Run
-- =========================================================

create extension if not exists pgcrypto;

create table if not exists public.careers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_emails (
  email text primary key,
  created_at timestamptz not null default now()
);

create table if not exists public.cycles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  order_number int not null unique,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  first_name text not null default '',
  last_name text not null default '',
  email text not null,
  career_id uuid references public.careers(id),
  current_cycle_id uuid references public.cycles(id),
  role text not null default 'student' check (role in ('student', 'admin')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.system_defaults (
  id boolean primary key default true,
  pc1_percent numeric(5,2) not null default 15,
  pc2_percent numeric(5,2) not null default 15,
  pc3_percent numeric(5,2) not null default 15,
  pc4_percent numeric(5,2) not null default 15,
  partial_percent numeric(5,2) not null default 20,
  final_percent numeric(5,2) not null default 20,
  minimum_grade numeric(5,2) not null default 11,
  updated_at timestamptz not null default now(),
  constraint system_defaults_single_row check (id = true),
  constraint system_defaults_sum check (
    pc1_percent + pc2_percent + pc3_percent + pc4_percent + partial_percent + final_percent = 100
  )
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  pc1_percent numeric(5,2) not null default 15,
  pc2_percent numeric(5,2) not null default 15,
  pc3_percent numeric(5,2) not null default 15,
  pc4_percent numeric(5,2) not null default 15,
  partial_percent numeric(5,2) not null default 20,
  final_percent numeric(5,2) not null default 20,
  minimum_grade numeric(5,2) not null default 11,
  updated_at timestamptz not null default now(),
  constraint user_settings_sum check (
    pc1_percent + pc2_percent + pc3_percent + pc4_percent + partial_percent + final_percent = 100
  )
);

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  career_id uuid not null references public.careers(id),
  cycle_id uuid references public.cycles(id),
  name text not null,
  created_by uuid references public.profiles(id),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.course_grades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  pc1 numeric(5,2) check (pc1 between 0 and 20),
  pc2 numeric(5,2) check (pc2 between 0 and 20),
  pc3 numeric(5,2) check (pc3 between 0 and 20),
  pc4 numeric(5,2) check (pc4 between 0 and 20),
  partial_exam numeric(5,2) check (partial_exam between 0 and 20),
  final_exam numeric(5,2) check (final_exam between 0 and 20),
  updated_at timestamptz not null default now(),
  unique(user_id, course_id)
);

create table if not exists public.calculation_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid references public.courses(id) on delete set null,
  pc1 numeric(5,2),
  pc2 numeric(5,2),
  pc3 numeric(5,2),
  pc4 numeric(5,2),
  partial_exam numeric(5,2),
  final_exam numeric(5,2),
  current_average numeric(5,2) not null,
  evaluated_weight numeric(5,2) not null,
  pending_weight numeric(5,2) not null,
  pending_evaluations text,
  required_average numeric(5,2),
  status text not null,
  created_at timestamptz not null default now()
);

insert into public.careers (name) values
('Ingeniería de Sistemas'),
('Contabilidad'),
('Administración'),
('Derecho'),
('Enfermería'),
('Psicología')
on conflict (name) do nothing;

insert into public.admin_emails (email) values
('oscar.miguel.huaman.cabrera@gmail.com')
on conflict (email) do nothing;

insert into public.system_defaults (id)
values (true)
on conflict (id) do nothing;

-- TABLAS NUEVAS / COLUMNAS NUEVAS
-- =========================================================

create table if not exists public.cycles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  order_number int not null unique,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now()
);

insert into public.cycles (name, order_number) values
('I ciclo', 1),
('II ciclo', 2),
('III ciclo', 3),
('IV ciclo', 4),
('V ciclo', 5),
('VI ciclo', 6),
('VII ciclo', 7),
('VIII ciclo', 8),
('IX ciclo', 9),
('X ciclo', 10)
on conflict (name) do nothing;

alter table public.profiles
  add column if not exists first_name text not null default '',
  add column if not exists last_name text not null default '',
  add column if not exists current_cycle_id uuid references public.cycles(id);

-- Mantiene compatibilidad con perfiles antiguos que solo tenían full_name.
update public.profiles
set first_name = case
    when first_name = '' and coalesce(full_name, '') <> '' then split_part(full_name, ' ', 1)
    else first_name
  end,
  last_name = case
    when last_name = '' and coalesce(full_name, '') <> '' then regexp_replace(full_name, '^\\S+\\s*', '')
    else last_name
  end
where coalesce(full_name, '') <> '';

-- Asigna I ciclo como ciclo inicial para usuarios existentes sin ciclo.
update public.profiles
set current_cycle_id = (select id from public.cycles where order_number = 1 limit 1)
where current_cycle_id is null;

alter table public.courses
  add column if not exists cycle_id uuid references public.cycles(id);

-- Asigna I ciclo como ciclo inicial para cursos antiguos sin ciclo.
update public.courses
set cycle_id = (select id from public.cycles where order_number = 1 limit 1)
where cycle_id is null;

-- Hace obligatorio el ciclo en cursos luego de corregir registros antiguos.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'courses' and column_name = 'cycle_id' and is_nullable = 'YES'
  ) then
    alter table public.courses alter column cycle_id set not null;
  end if;
exception when others then
  raise notice 'No se pudo marcar courses.cycle_id como NOT NULL: %', sqlerrm;
end $$;

-- Índice anterior: carrera + nombre. Ahora debe ser carrera + ciclo + nombre.
drop index if exists public.courses_career_name_unique;
create unique index if not exists courses_career_cycle_name_unique
on public.courses (career_id, cycle_id, lower(trim(name)))
where status = 'active';

create table if not exists public.login_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  login_at timestamptz not null default now(),
  login_date date not null default current_date,
  user_agent text,
  role text,
  career_id uuid references public.careers(id),
  cycle_id uuid references public.cycles(id)
);

create index if not exists login_activity_date_idx on public.login_activity (login_date desc);
create index if not exists login_activity_user_idx on public.login_activity (user_id);
create index if not exists login_activity_career_cycle_idx on public.login_activity (career_id, cycle_id);

-- =========================================================
-- FUNCIONES ACTUALIZADAS
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
      and p.status = 'active'
  )
  or exists (
    select 1 from public.admin_emails a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

create or replace function public.is_active_user()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.status = 'active'
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_career uuid;
  selected_cycle uuid;
  new_role text;
  meta_first text;
  meta_last text;
  meta_full text;
begin
  selected_career := nullif(new.raw_user_meta_data ->> 'career_id', '')::uuid;
  selected_cycle := nullif(new.raw_user_meta_data ->> 'current_cycle_id', '')::uuid;
  meta_first := coalesce(new.raw_user_meta_data ->> 'first_name', '');
  meta_last := coalesce(new.raw_user_meta_data ->> 'last_name', '');
  meta_full := coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '');

  if meta_first = '' and meta_full <> '' then
    meta_first := split_part(meta_full, ' ', 1);
  end if;

  if meta_last = '' and meta_full <> '' then
    meta_last := regexp_replace(meta_full, '^\\S+\\s*', '');
  end if;

  if selected_cycle is null then
    selected_cycle := (select id from public.cycles where order_number = 1 limit 1);
  end if;

  if exists (
    select 1 from public.admin_emails
    where lower(email) = lower(new.email)
  ) then
    new_role := 'admin';
  else
    new_role := 'student';
  end if;

  insert into public.profiles (
    id,
    full_name,
    first_name,
    last_name,
    email,
    career_id,
    current_cycle_id,
    role,
    status
  )
  values (
    new.id,
    trim(coalesce(meta_first, '') || ' ' || coalesce(meta_last, '')),
    coalesce(meta_first, ''),
    coalesce(meta_last, ''),
    new.email,
    selected_career,
    selected_cycle,
    new_role,
    'active'
  )
  on conflict (id) do update set
    email = excluded.email,
    role = excluded.role,
    updated_at = now();

  insert into public.user_settings (
    user_id,
    pc1_percent,
    pc2_percent,
    pc3_percent,
    pc4_percent,
    partial_percent,
    final_percent,
    minimum_grade
  )
  select
    new.id,
    pc1_percent,
    pc2_percent,
    pc3_percent,
    pc4_percent,
    partial_percent,
    final_percent,
    minimum_grade
  from public.system_defaults
  where id = true
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- Trigger de nuevos usuarios
 drop trigger if exists on_auth_user_created on auth.users;
 create trigger on_auth_user_created
 after insert on auth.users
 for each row execute function public.handle_new_user();

-- Triggers updated_at
 drop trigger if exists set_profiles_updated_at on public.profiles;
 create trigger set_profiles_updated_at
 before update on public.profiles
 for each row execute function public.set_updated_at();

 drop trigger if exists set_courses_updated_at on public.courses;
 create trigger set_courses_updated_at
 before update on public.courses
 for each row execute function public.set_updated_at();

 drop trigger if exists set_user_settings_updated_at on public.user_settings;
 create trigger set_user_settings_updated_at
 before update on public.user_settings
 for each row execute function public.set_updated_at();

 drop trigger if exists set_course_grades_updated_at on public.course_grades;
 create trigger set_course_grades_updated_at
 before update on public.course_grades
 for each row execute function public.set_updated_at();

-- =========================================================
-- RLS: limpiar políticas anteriores y recrear
-- =========================================================

do $$
declare
  r record;
begin
  for r in (
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'careers', 'cycles', 'admin_emails', 'profiles', 'system_defaults',
        'user_settings', 'courses', 'course_grades', 'calculation_history', 'login_activity'
      )
  ) loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

alter table public.careers enable row level security;
alter table public.cycles enable row level security;
alter table public.admin_emails enable row level security;
alter table public.profiles enable row level security;
alter table public.system_defaults enable row level security;
alter table public.user_settings enable row level security;
alter table public.courses enable row level security;
alter table public.course_grades enable row level security;
alter table public.calculation_history enable row level security;
alter table public.login_activity enable row level security;

-- CARRERAS
create policy "Careers visibles activas" on public.careers
for select using (status = 'active' or public.is_admin());

create policy "Admin gestiona carreras" on public.careers
for all using (public.is_admin()) with check (public.is_admin());

-- CICLOS
create policy "Cycles visibles activos" on public.cycles
for select using (status = 'active' or public.is_admin());

create policy "Admin gestiona ciclos" on public.cycles
for all using (public.is_admin()) with check (public.is_admin());

-- ADMIN EMAILS
create policy "Admin ve correos admin" on public.admin_emails
for select using (public.is_admin());

create policy "Admin gestiona correos admin" on public.admin_emails
for all using (public.is_admin()) with check (public.is_admin());

-- PROFILES
create policy "Usuario ve su perfil o admin ve todos" on public.profiles
for select using (id = auth.uid() or public.is_admin());

create policy "Usuario actualiza datos basicos" on public.profiles
for update
using (id = auth.uid() and status = 'active')
with check (id = auth.uid() and role = 'student' and status = 'active');

create policy "Admin actualiza perfiles" on public.profiles
for update
using (public.is_admin())
with check (public.is_admin());

-- SYSTEM DEFAULTS
create policy "Todos ven valores por defecto" on public.system_defaults
for select using (true);

create policy "Admin actualiza valores por defecto" on public.system_defaults
for update using (public.is_admin()) with check (public.is_admin());

-- USER SETTINGS
create policy "Usuario ve sus ajustes o admin ve todos" on public.user_settings
for select using (user_id = auth.uid() or public.is_admin());

create policy "Usuario crea sus ajustes" on public.user_settings
for insert with check (user_id = auth.uid() and public.is_active_user());

create policy "Usuario actualiza sus ajustes" on public.user_settings
for update
using (user_id = auth.uid() and public.is_active_user())
with check (user_id = auth.uid());

create policy "Admin gestiona ajustes" on public.user_settings
for all using (public.is_admin()) with check (public.is_admin());

-- COURSES
create policy "Cursos visibles por carrera y ciclo" on public.courses
for select using (
  public.is_admin()
  or (
    status = 'active'
    and career_id in (select career_id from public.profiles where id = auth.uid())
    and cycle_id in (select current_cycle_id from public.profiles where id = auth.uid())
  )
);

create policy "Usuario crea cursos en su carrera y ciclo" on public.courses
for insert with check (
  public.is_active_user()
  and created_by = auth.uid()
  and career_id in (select career_id from public.profiles where id = auth.uid())
  and cycle_id in (select current_cycle_id from public.profiles where id = auth.uid())
);

create policy "Admin actualiza cursos" on public.courses
for update using (public.is_admin()) with check (public.is_admin());

create policy "Admin elimina cursos" on public.courses
for delete using (public.is_admin());

-- COURSE GRADES
create policy "Usuario ve sus notas o admin ve todas" on public.course_grades
for select using (user_id = auth.uid() or public.is_admin());

create policy "Usuario crea sus notas" on public.course_grades
for insert with check (user_id = auth.uid() and public.is_active_user());

create policy "Usuario actualiza sus notas" on public.course_grades
for update using (user_id = auth.uid() and public.is_active_user()) with check (user_id = auth.uid());

create policy "Usuario elimina sus notas o admin elimina" on public.course_grades
for delete using (user_id = auth.uid() or public.is_admin());

-- CALCULATION HISTORY
create policy "Usuario ve su historial o admin ve todo" on public.calculation_history
for select using (user_id = auth.uid() or public.is_admin());

create policy "Usuario guarda su historial" on public.calculation_history
for insert with check (user_id = auth.uid() and public.is_active_user());

create policy "Usuario elimina su historial o admin elimina" on public.calculation_history
for delete using (user_id = auth.uid() or public.is_admin());

-- LOGIN ACTIVITY
create policy "Usuario registra su login" on public.login_activity
for insert with check (user_id = auth.uid());

create policy "Usuario ve sus accesos o admin ve todos" on public.login_activity
for select using (user_id = auth.uid() or public.is_admin());

create policy "Admin gestiona actividad login" on public.login_activity
for all using (public.is_admin()) with check (public.is_admin());

-- =========================================================
-- VERIFICACIÓN RÁPIDA
-- =========================================================
-- select * from public.cycles order by order_number;
-- select email, role, status, first_name, last_name from public.profiles order by created_at desc;
