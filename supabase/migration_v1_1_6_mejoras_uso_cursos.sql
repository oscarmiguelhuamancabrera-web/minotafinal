-- ============================================================
-- MI NOTA FINAL v1.1.6
-- Mejoras: ajustes por usuario, invitado temporal, analítica real,
-- solicitudes de cursos no listados y saneamiento de nombres Google.
-- ============================================================

create extension if not exists "pgcrypto";

-- 1. Corrección de nombres Google duplicados en auth.users
with usuarios as (
  select
    id,
    raw_user_meta_data,
    trim(coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', '')) as full_name
  from auth.users
  where raw_user_meta_data is not null
), separado as (
  select
    id,
    raw_user_meta_data,
    full_name,
    regexp_split_to_array(full_name, '\s+') as partes
  from usuarios
  where full_name <> ''
), corregido as (
  select
    id,
    full_name,
    case
      when array_length(partes, 1) >= 2 and lower(partes[1]) = lower(partes[2])
        then array_to_string(partes[2:array_length(partes, 1)], ' ')
      else full_name
    end as nuevo_full_name
  from separado
)
update auth.users u
set raw_user_meta_data =
  jsonb_set(
    jsonb_set(coalesce(u.raw_user_meta_data, '{}'::jsonb), '{full_name}', to_jsonb(c.nuevo_full_name)),
    '{name}', to_jsonb(c.nuevo_full_name)
  )
from corregido c
where u.id = c.id
  and c.full_name <> c.nuevo_full_name;

-- 2. Corrección de profiles first_name/last_name cuando last_name contiene nombre completo
with perfiles as (
  select
    p.id,
    trim(coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', p.first_name || ' ' || p.last_name)) as full_name
  from public.profiles p
  left join auth.users u on u.id = p.id
  where coalesce(p.role, 'student') not in ('admin', 'superadmin')
), limpio as (
  select
    id,
    case
      when array_length(regexp_split_to_array(full_name, '\s+'), 1) >= 2
        and lower((regexp_split_to_array(full_name, '\s+'))[1]) = lower((regexp_split_to_array(full_name, '\s+'))[2])
        then array_to_string((regexp_split_to_array(full_name, '\s+'))[2:array_length(regexp_split_to_array(full_name, '\s+'), 1)], ' ')
      else full_name
    end as full_name
  from perfiles
), partes as (
  select id, regexp_split_to_array(trim(full_name), '\s+') as p
  from limpio
  where trim(full_name) <> ''
), nombres as (
  select
    id,
    case
      when array_length(p, 1) = 1 then p[1]
      when array_length(p, 1) = 2 then p[1]
      when array_length(p, 1) = 3 then p[1]
      when array_length(p, 1) >= 4 then p[1] || ' ' || p[2]
      else p[1]
    end as first_name,
    case
      when array_length(p, 1) = 1 then ''
      when array_length(p, 1) = 2 then p[2]
      when array_length(p, 1) = 3 then p[2] || ' ' || p[3]
      when array_length(p, 1) >= 4 then array_to_string(p[3:array_length(p, 1)], ' ')
      else ''
    end as last_name
  from partes
)
update public.profiles p
set first_name = n.first_name,
    last_name = n.last_name,
    full_name = trim(n.first_name || ' ' || n.last_name),
    updated_at = now()
from nombres n
where p.id = n.id;

-- 3. Ajustes personalizados por usuario: solo porcentajes y nota mínima
create table if not exists public.user_evaluation_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  template_id uuid not null references public.evaluation_templates(id) on delete cascade,
  min_passing_grade numeric(5,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, template_id)
);

create table if not exists public.user_evaluation_component_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  template_id uuid not null references public.evaluation_templates(id) on delete cascade,
  component_id uuid not null references public.evaluation_components(id) on delete cascade,
  weight_percent numeric(6,2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, component_id)
);

alter table public.user_evaluation_settings enable row level security;
alter table public.user_evaluation_component_settings enable row level security;

drop policy if exists "Usuario ve sus ajustes de plantilla" on public.user_evaluation_settings;
create policy "Usuario ve sus ajustes de plantilla"
on public.user_evaluation_settings
for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Usuario guarda sus ajustes de plantilla" on public.user_evaluation_settings;
create policy "Usuario guarda sus ajustes de plantilla"
on public.user_evaluation_settings
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Usuario actualiza sus ajustes de plantilla" on public.user_evaluation_settings;
create policy "Usuario actualiza sus ajustes de plantilla"
on public.user_evaluation_settings
for update
to authenticated
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "Usuario ve sus porcentajes" on public.user_evaluation_component_settings;
create policy "Usuario ve sus porcentajes"
on public.user_evaluation_component_settings
for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Usuario guarda sus porcentajes" on public.user_evaluation_component_settings;
create policy "Usuario guarda sus porcentajes"
on public.user_evaluation_component_settings
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Usuario actualiza sus porcentajes" on public.user_evaluation_component_settings;
create policy "Usuario actualiza sus porcentajes"
on public.user_evaluation_component_settings
for update
to authenticated
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

-- 4. Analítica de uso real
create table if not exists public.app_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  event_type text not null,
  university_id uuid references public.universities(id),
  faculty_id uuid references public.faculties(id),
  career_id uuid references public.careers(id),
  cycle_id uuid references public.cycles(id),
  course_id uuid references public.courses(id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists app_usage_events_user_idx on public.app_usage_events(user_id);
create index if not exists app_usage_events_event_type_idx on public.app_usage_events(event_type);
create index if not exists app_usage_events_created_at_idx on public.app_usage_events(created_at desc);

alter table public.app_usage_events enable row level security;

drop policy if exists "Usuario registra uso real" on public.app_usage_events;
create policy "Usuario registra uso real"
on public.app_usage_events
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Usuario ve su uso o admin todos" on public.app_usage_events;
create policy "Usuario ve su uso o admin todos"
on public.app_usage_events
for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

-- 5. Solicitudes de cursos no listados, con registro de quién lo solicitó
create table if not exists public.course_requests (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references public.profiles(id) on delete cascade,
  university_id uuid not null references public.universities(id),
  faculty_id uuid not null references public.faculties(id),
  career_id uuid not null references public.careers(id),
  cycle_id uuid not null references public.cycles(id),
  proposed_name text not null,
  enrollment_type text not null default 'regular',
  status text not null default 'pending',
  similar_courses jsonb not null default '[]'::jsonb,
  linked_course_id uuid references public.courses(id),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists course_requests_status_idx on public.course_requests(status);
create index if not exists course_requests_requested_by_idx on public.course_requests(requested_by);
create index if not exists course_requests_context_idx on public.course_requests(university_id, faculty_id, career_id, cycle_id);

alter table public.course_requests enable row level security;

drop policy if exists "Usuario crea solicitud de curso" on public.course_requests;
create policy "Usuario crea solicitud de curso"
on public.course_requests
for insert
to authenticated
with check (requested_by = auth.uid());

drop policy if exists "Usuario ve sus solicitudes o admin todas" on public.course_requests;
create policy "Usuario ve sus solicitudes o admin todas"
on public.course_requests
for select
to authenticated
using (requested_by = auth.uid() or public.is_admin());

drop policy if exists "Admin gestiona solicitudes de cursos" on public.course_requests;
create policy "Admin gestiona solicitudes de cursos"
on public.course_requests
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- 6. Mantener cursos: alumnos no deberían crear oficiales directamente desde calculadora.
-- La tabla courses conserva created_by para trazabilidad cuando el admin apruebe o cree cursos.

select 'v1.1.6 listo: ajustes por usuario, analítica real, solicitudes de cursos y saneamiento de nombres.' as resultado;
