-- ============================================================
-- MI NOTA FINAL WEB/PWA v1.1.0 (corregido en paquete v1.1.1)
-- MIGRACIÓN MULTIUNIVERSIDAD + EVALUACIONES CONFIGURABLES
-- Base requerida: v1.0.6 validada
-- Ejecutar en Supabase > SQL Editor > New query > Run
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 0. Compatibilidad de roles
-- ============================================================

do $$
begin
  alter table public.profiles drop constraint if exists profiles_role_check;
  alter table public.profiles
    add constraint profiles_role_check
    check (role in ('student', 'admin', 'superadmin'));
exception when others then
  raise notice 'No se pudo actualizar check de roles: %', sqlerrm;
end $$;

-- ============================================================
-- 1. Universidades y facultades
-- ============================================================

create table if not exists public.universities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists universities_code_unique
on public.universities (lower(trim(code)));

create table if not exists public.faculties (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references public.universities(id) on delete restrict,
  name text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists faculties_university_name_unique
on public.faculties (university_id, lower(trim(name)));

insert into public.universities (name, code, status)
values
('Universidad Privada San Juan Bautista', 'UPSJB', 'active'),
('Universidad Autónoma de Ica', 'UAI', 'active')
on conflict do nothing;

with u as (select id from public.universities where lower(code) = 'upsjb' limit 1),
data(name) as (
  values
  ('Facultad de Ciencias de la Salud'),
  ('Facultad de Ingenierías'),
  ('Facultad de Derecho y Ciencias Empresariales')
)
insert into public.faculties (university_id, name, status)
select u.id, d.name, 'active'
from data d cross join u
where not exists (
  select 1 from public.faculties f
  where f.university_id = u.id and lower(trim(f.name)) = lower(trim(d.name))
);

with u as (select id from public.universities where lower(code) = 'uai' limit 1),
data(name) as (
  values
  ('Facultad de Ingeniería, Ciencias y Administración'),
  ('Facultad de Ciencias de la Salud')
)
insert into public.faculties (university_id, name, status)
select u.id, d.name, 'active'
from data d cross join u
where not exists (
  select 1 from public.faculties f
  where f.university_id = u.id and lower(trim(f.name)) = lower(trim(d.name))
);

-- ============================================================
-- 2. Carreras asociadas a facultad/universidad
-- ============================================================

alter table public.careers add column if not exists faculty_id uuid;
alter table public.careers add column if not exists status text not null default 'active';
alter table public.careers add column if not exists updated_at timestamptz not null default now();

alter table public.careers drop constraint if exists careers_name_key;
drop index if exists public.careers_name_unique;
drop index if exists public.careers_name_key;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'careers_faculty_id_fkey') then
    alter table public.careers
      add constraint careers_faculty_id_fkey
      foreign key (faculty_id) references public.faculties(id) on delete restrict;
  end if;
exception when others then
  raise notice 'No se pudo crear FK careers_faculty_id_fkey: %', sqlerrm;
end $$;

create unique index if not exists careers_faculty_name_unique
on public.careers (faculty_id, lower(trim(name)))
where status = 'active';

update public.careers
set name = 'Administración de Empresas', updated_at = now()
where lower(trim(name)) = lower('Administración');

-- UPSJB carreras oficiales
with data(faculty_name, career_name) as (
  values
  ('Facultad de Ciencias de la Salud', 'Medicina Humana'),
  ('Facultad de Ciencias de la Salud', 'Psicología'),
  ('Facultad de Ciencias de la Salud', 'Tecnología Médica en Laboratorio Clínico y Anatomía Patológica'),
  ('Facultad de Ciencias de la Salud', 'Tecnología Médica en Terapia Física y Rehabilitación'),
  ('Facultad de Ciencias de la Salud', 'Enfermería'),
  ('Facultad de Ciencias de la Salud', 'Estomatología / Odontología'),
  ('Facultad de Ciencias de la Salud', 'Medicina Veterinaria y Zootecnia'),
  ('Facultad de Ingenierías', 'Ingeniería de Sistemas'),
  ('Facultad de Ingenierías', 'Ingeniería Civil'),
  ('Facultad de Ingenierías', 'Ingeniería Agroindustrial'),
  ('Facultad de Ingenierías', 'Ingeniería en Enología y Viticultura'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Derecho'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Contabilidad'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Administración de Empresas'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Administración y Negocios Internacionales'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Administración y Marketing'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Turismo, Hotelería y Gastronomía')
), u as (select id from public.universities where lower(code) = 'upsjb' limit 1)
insert into public.careers (faculty_id, name, status)
select f.id, d.career_name, 'active'
from data d
cross join u
join public.faculties f on f.university_id = u.id and lower(trim(f.name)) = lower(trim(d.faculty_name))
where not exists (
  select 1 from public.careers c
  where c.faculty_id = f.id and lower(trim(c.name)) = lower(trim(d.career_name))
);

-- Asigna carreras antiguas a UPSJB
with data(faculty_name, career_name) as (
  values
  ('Facultad de Ciencias de la Salud', 'Psicología'),
  ('Facultad de Ciencias de la Salud', 'Enfermería'),
  ('Facultad de Ingenierías', 'Ingeniería de Sistemas'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Derecho'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Contabilidad'),
  ('Facultad de Derecho y Ciencias Empresariales', 'Administración de Empresas')
), u as (select id from public.universities where lower(code) = 'upsjb' limit 1)
update public.careers c
set faculty_id = f.id, updated_at = now(), status = 'active'
from data d
cross join u
join public.faculties f on f.university_id = u.id and lower(trim(f.name)) = lower(trim(d.faculty_name))
where lower(trim(c.name)) = lower(trim(d.career_name))
  and c.faculty_id is null;

-- UAI carreras oficiales
with data(faculty_name, career_name) as (
  values
  ('Facultad de Ingeniería, Ciencias y Administración', 'Arquitectura'),
  ('Facultad de Ingeniería, Ciencias y Administración', 'Ingeniería Civil'),
  ('Facultad de Ingeniería, Ciencias y Administración', 'Ingeniería Industrial'),
  ('Facultad de Ingeniería, Ciencias y Administración', 'Contabilidad'),
  ('Facultad de Ingeniería, Ciencias y Administración', 'Administración de Empresas'),
  ('Facultad de Ingeniería, Ciencias y Administración', 'Derecho'),
  ('Facultad de Ingeniería, Ciencias y Administración', 'Ingeniería de Sistemas'),
  ('Facultad de Ciencias de la Salud', 'Tecnología Médica en Optometría'),
  ('Facultad de Ciencias de la Salud', 'Tecnología Médica en Terapia Física y Rehabilitación'),
  ('Facultad de Ciencias de la Salud', 'Tecnología Médica en Terapia de Lenguaje'),
  ('Facultad de Ciencias de la Salud', 'Tecnología Médica en Laboratorio Clínico y Anatomía Patológica'),
  ('Facultad de Ciencias de la Salud', 'Medicina Humana'),
  ('Facultad de Ciencias de la Salud', 'Enfermería'),
  ('Facultad de Ciencias de la Salud', 'Obstetricia'),
  ('Facultad de Ciencias de la Salud', 'Psicología')
), u as (select id from public.universities where lower(code) = 'uai' limit 1)
insert into public.careers (faculty_id, name, status)
select f.id, d.career_name, 'active'
from data d
cross join u
join public.faculties f on f.university_id = u.id and lower(trim(f.name)) = lower(trim(d.faculty_name))
where not exists (
  select 1 from public.careers c
  where c.faculty_id = f.id and lower(trim(c.name)) = lower(trim(d.career_name))
);

-- ============================================================
-- 3. Perfil académico multiuniversidad
-- ============================================================

alter table public.profiles add column if not exists university_id uuid;
alter table public.profiles add column if not exists faculty_id uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_university_id_fkey') then
    alter table public.profiles add constraint profiles_university_id_fkey foreign key (university_id) references public.universities(id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_faculty_id_fkey') then
    alter table public.profiles add constraint profiles_faculty_id_fkey foreign key (faculty_id) references public.faculties(id) on delete restrict;
  end if;
exception when others then
  raise notice 'No se pudo crear FK en profiles: %', sqlerrm;
end $$;

with upsjb as (select id from public.universities where lower(code) = 'upsjb' limit 1)
update public.profiles p
set university_id = u.id,
    updated_at = now()
from upsjb u
where coalesce(p.role, 'student') = 'student'
  and (p.university_id is null or p.university_id <> u.id);

update public.profiles p
set faculty_id = c.faculty_id,
    updated_at = now()
from public.careers c
where p.career_id = c.id
  and coalesce(p.role, 'student') = 'student'
  and p.faculty_id is null;

-- Admin/superadmin sin universidad por defecto.
update public.profiles
set university_id = null,
    faculty_id = null,
    career_id = null,
    current_cycle_id = null,
    updated_at = now()
where coalesce(role, '') in ('admin', 'superadmin')
   or lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com');

create table if not exists public.profile_academic_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  old_university_id uuid references public.universities(id),
  old_faculty_id uuid references public.faculties(id),
  old_career_id uuid references public.careers(id),
  old_cycle_id uuid references public.cycles(id),
  new_university_id uuid references public.universities(id),
  new_faculty_id uuid references public.faculties(id),
  new_career_id uuid references public.careers(id),
  new_cycle_id uuid references public.cycles(id),
  changed_by uuid,
  changed_at timestamptz not null default now()
);

create or replace function public.validate_profile_academic_context()
returns trigger
language plpgsql
as $$
declare
  faculty_university uuid;
  career_faculty uuid;
begin
  if coalesce(new.role, '') in ('admin', 'superadmin') then
    return new;
  end if;

  if new.faculty_id is not null and new.university_id is not null then
    select university_id into faculty_university from public.faculties where id = new.faculty_id;
    if faculty_university is distinct from new.university_id then
      raise exception 'La facultad seleccionada no pertenece a la universidad seleccionada.';
    end if;
  end if;

  if new.career_id is not null and new.faculty_id is not null then
    select faculty_id into career_faculty from public.careers where id = new.career_id;
    if career_faculty is distinct from new.faculty_id then
      raise exception 'La carrera seleccionada no pertenece a la facultad seleccionada.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_profile_academic_context on public.profiles;
create trigger trg_validate_profile_academic_context
before insert or update of university_id, faculty_id, career_id, current_cycle_id, role
on public.profiles
for each row execute function public.validate_profile_academic_context();

create or replace function public.log_profile_academic_change()
returns trigger
language plpgsql
as $$
begin
  if old.university_id is distinct from new.university_id
     or old.faculty_id is distinct from new.faculty_id
     or old.career_id is distinct from new.career_id
     or old.current_cycle_id is distinct from new.current_cycle_id then
    insert into public.profile_academic_history (
      user_id, old_university_id, old_faculty_id, old_career_id, old_cycle_id,
      new_university_id, new_faculty_id, new_career_id, new_cycle_id, changed_by
    ) values (
      new.id, old.university_id, old.faculty_id, old.career_id, old.current_cycle_id,
      new.university_id, new.faculty_id, new.career_id, new.current_cycle_id, auth.uid()
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_log_profile_academic_change on public.profiles;
create trigger trg_log_profile_academic_change
after update of university_id, faculty_id, career_id, current_cycle_id
on public.profiles
for each row execute function public.log_profile_academic_change();

-- ============================================================
-- 4. Cursos multiuniversidad
-- ============================================================

alter table public.courses add column if not exists university_id uuid;
alter table public.courses add column if not exists faculty_id uuid;
alter table public.courses add column if not exists evaluation_template_id uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'courses_university_id_fkey') then
    alter table public.courses add constraint courses_university_id_fkey foreign key (university_id) references public.universities(id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'courses_faculty_id_fkey') then
    alter table public.courses add constraint courses_faculty_id_fkey foreign key (faculty_id) references public.faculties(id) on delete restrict;
  end if;
exception when others then
  raise notice 'No se pudo crear FK en courses: %', sqlerrm;
end $$;

update public.courses c
set faculty_id = ca.faculty_id,
    university_id = f.university_id,
    updated_at = now()
from public.careers ca
join public.faculties f on f.id = ca.faculty_id
where c.career_id = ca.id
  and (c.faculty_id is null or c.university_id is null);

drop index if exists public.courses_career_cycle_name_unique;
drop index if exists public.courses_career_name_unique;

create unique index if not exists courses_context_cycle_name_unique
on public.courses (university_id, faculty_id, career_id, cycle_id, lower(trim(name)))
where status = 'active';

-- ============================================================
-- 5. Métodos de evaluación configurables
-- ============================================================

create table if not exists public.evaluation_templates (
  id uuid primary key default gen_random_uuid(),
  university_id uuid references public.universities(id) on delete restrict,
  faculty_id uuid references public.faculties(id) on delete restrict,
  career_id uuid references public.careers(id) on delete restrict,
  course_id uuid references public.courses(id) on delete restrict,
  name text not null,
  description text,
  min_passing_grade numeric(5,2) not null default 11,
  scale_min numeric(5,2) not null default 0,
  scale_max numeric(5,2) not null default 20,
  status text not null default 'draft' check (status in ('draft', 'active', 'inactive')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.evaluation_components (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.evaluation_templates(id) on delete cascade,
  name text not null,
  short_name text not null,
  weight_percent numeric(6,2) not null check (weight_percent >= 0 and weight_percent <= 100),
  component_order integer not null default 1,
  unit_name text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists evaluation_template_name_context_unique
on public.evaluation_templates (
  coalesce(university_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(faculty_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(career_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(course_id, '00000000-0000-0000-0000-000000000000'::uuid),
  lower(trim(name))
);

create unique index if not exists evaluation_component_template_order_unique
on public.evaluation_components (template_id, component_order);

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
    where template_id = new.id and status = 'active';
    if abs(total - 100.00) > 0.01 then
      raise exception 'El método de evaluación debe sumar 100%%. Actualmente suma: %', total;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_evaluation_template_total_on_active on public.evaluation_templates;
create trigger trg_check_evaluation_template_total_on_active
before update of status on public.evaluation_templates
for each row execute function public.check_evaluation_template_total_on_active();

-- Plantilla UPSJB estándar
with u as (select id from public.universities where lower(code) = 'upsjb' limit 1)
insert into public.evaluation_templates (university_id, name, description, min_passing_grade, status)
select u.id, 'UPSJB - Evaluación estándar', 'PC1, PC2, PC3, PC4, Parcial y Final', 11, 'draft'
from u
where not exists (
  select 1 from public.evaluation_templates et where et.university_id = u.id and lower(trim(et.name)) = lower('UPSJB - Evaluación estándar')
);

with t as (select id from public.evaluation_templates where lower(trim(name)) = lower('UPSJB - Evaluación estándar') limit 1),
data(component_order, short_name, name, unit_name, weight_percent) as (
  values
  (1, 'PC1', 'Práctica Calificada 1', null, 15.00),
  (2, 'PC2', 'Práctica Calificada 2', null, 15.00),
  (3, 'PC3', 'Práctica Calificada 3', null, 15.00),
  (4, 'PC4', 'Práctica Calificada 4', null, 15.00),
  (5, 'Parcial', 'Examen Parcial', null, 20.00),
  (6, 'Final', 'Examen Final', null, 20.00)
)
insert into public.evaluation_components (template_id, component_order, short_name, name, unit_name, weight_percent, status)
select t.id, d.component_order, d.short_name, d.name, d.unit_name, d.weight_percent, 'active'
from data d cross join t
where not exists (
  select 1 from public.evaluation_components ec where ec.template_id = t.id and ec.component_order = d.component_order
);

update public.evaluation_templates
set status = 'active', updated_at = now()
where lower(trim(name)) = lower('UPSJB - Evaluación estándar');

-- Plantilla UAI según imagen compartida
with u as (select id from public.universities where lower(code) = 'uai' limit 1)
insert into public.evaluation_templates (university_id, name, description, min_passing_grade, status)
select u.id, 'UAI - Evaluación por unidades', 'FK1, FK2 y evaluaciones sumativas U1, U2 y U3', 11, 'draft'
from u
where not exists (
  select 1 from public.evaluation_templates et where et.university_id = u.id and lower(trim(et.name)) = lower('UAI - Evaluación por unidades')
);

with t as (select id from public.evaluation_templates where lower(trim(name)) = lower('UAI - Evaluación por unidades') limit 1),
data(component_order, short_name, name, unit_name, weight_percent) as (
  values
  (1, 'FK1-U1', 'FK1 1.ª unidad', 'Unidad 1', 8.33),
  (2, 'FK2-U1', 'FK2 1.ª unidad', 'Unidad 1', 8.33),
  (3, 'U1', 'U1 Evaluación Sumativa', 'Unidad 1', 10.00),
  (4, 'FK1-U2', 'FK1 2.ª unidad', 'Unidad 2', 8.33),
  (5, 'FK2-U2', 'FK2 2.ª unidad', 'Unidad 2', 8.33),
  (6, 'U2', 'U2 Evaluación Sumativa', 'Unidad 2', 15.00),
  (7, 'FK1-U3', 'FK1 3.ª unidad', 'Unidad 3', 8.34),
  (8, 'FK2-U3', 'FK2 3.ª unidad', 'Unidad 3', 8.34),
  (9, 'U3', 'U3 Evaluación Sumativa', 'Unidad 3', 25.00)
)
insert into public.evaluation_components (template_id, component_order, short_name, name, unit_name, weight_percent, status)
select t.id, d.component_order, d.short_name, d.name, d.unit_name, d.weight_percent, 'active'
from data d cross join t
where not exists (
  select 1 from public.evaluation_components ec where ec.template_id = t.id and ec.component_order = d.component_order
);

update public.evaluation_templates
set status = 'active', updated_at = now()
where lower(trim(name)) = lower('UAI - Evaluación por unidades');

-- FK de cursos a plantilla después de crear tabla

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'courses_evaluation_template_id_fkey') then
    alter table public.courses add constraint courses_evaluation_template_id_fkey foreign key (evaluation_template_id) references public.evaluation_templates(id) on delete set null;
  end if;
exception when others then
  raise notice 'No se pudo crear FK courses_evaluation_template_id_fkey: %', sqlerrm;
end $$;

-- Asignar plantilla estándar a cursos existentes por universidad
update public.courses c
set evaluation_template_id = et.id, updated_at = now()
from public.evaluation_templates et
where c.university_id = et.university_id
  and c.evaluation_template_id is null
  and et.status = 'active'
  and (
    (exists (select 1 from public.universities u where u.id = et.university_id and lower(u.code) = 'upsjb') and lower(trim(et.name)) = lower('UPSJB - Evaluación estándar'))
    or
    (exists (select 1 from public.universities u where u.id = et.university_id and lower(u.code) = 'uai') and lower(trim(et.name)) = lower('UAI - Evaluación por unidades'))
  );

-- ============================================================
-- 6. Mis cursos actuales y notas flexibles
-- ============================================================

alter table public.student_courses add column if not exists university_id uuid references public.universities(id);
alter table public.student_courses add column if not exists faculty_id uuid references public.faculties(id);
alter table public.student_courses add column if not exists career_id uuid references public.careers(id);
alter table public.student_courses add column if not exists cycle_id uuid references public.cycles(id);
alter table public.student_courses add column if not exists hidden_at timestamptz;

update public.student_courses sc
set university_id = c.university_id,
    faculty_id = c.faculty_id,
    career_id = c.career_id,
    cycle_id = c.cycle_id,
    hidden_at = case when sc.status = 'hidden' then coalesce(sc.hidden_at, now()) else sc.hidden_at end,
    updated_at = now()
from public.courses c
where sc.course_id = c.id
  and (sc.university_id is null or sc.faculty_id is null or sc.career_id is null or sc.cycle_id is null);

create table if not exists public.student_evaluation_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  student_course_id uuid references public.student_courses(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete restrict,
  evaluation_template_id uuid references public.evaluation_templates(id) on delete restrict,
  evaluation_component_id uuid not null references public.evaluation_components(id) on delete restrict,
  score numeric(5,2) check (score between 0 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists student_eval_score_unique
on public.student_evaluation_scores (user_id, course_id, evaluation_component_id);

alter table public.calculation_history add column if not exists evaluation_template_id uuid references public.evaluation_templates(id);
alter table public.calculation_history add column if not exists evaluation_snapshot jsonb;

-- Compatibilidad login activity
alter table public.login_activity add column if not exists university_id uuid references public.universities(id);
alter table public.login_activity add column if not exists faculty_id uuid references public.faculties(id);

-- ============================================================
-- 7. Funciones admin y RLS
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and coalesce(p.role, '') in ('admin', 'superadmin')
  );
$$;

alter table public.universities enable row level security;
alter table public.faculties enable row level security;
alter table public.evaluation_templates enable row level security;
alter table public.evaluation_components enable row level security;
alter table public.profile_academic_history enable row level security;
alter table public.student_evaluation_scores enable row level security;

-- Universidades
DROP POLICY IF EXISTS "Catalogo universidades activo" ON public.universities;
CREATE POLICY "Catalogo universidades activo" ON public.universities
FOR SELECT TO anon, authenticated
USING (status = 'active' OR public.is_admin());
DROP POLICY IF EXISTS "Admin gestiona universidades" ON public.universities;
CREATE POLICY "Admin gestiona universidades" ON public.universities
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Facultades
DROP POLICY IF EXISTS "Catalogo facultades activo" ON public.faculties;
CREATE POLICY "Catalogo facultades activo" ON public.faculties
FOR SELECT TO anon, authenticated
USING (status = 'active' OR public.is_admin());
DROP POLICY IF EXISTS "Admin gestiona facultades" ON public.faculties;
CREATE POLICY "Admin gestiona facultades" ON public.faculties
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Carreras visibles
DROP POLICY IF EXISTS "Carreras visibles" ON public.careers;
CREATE POLICY "Carreras visibles" ON public.careers
FOR SELECT TO anon, authenticated
USING (status = 'active' OR public.is_admin());

-- Cursos oficiales por contexto multiuniversidad
DROP POLICY IF EXISTS "Cursos visibles por carrera" ON public.courses;
DROP POLICY IF EXISTS "Cursos visibles por carrera y ciclo" ON public.courses;
DROP POLICY IF EXISTS "Cursos visibles por contexto academico" ON public.courses;
CREATE POLICY "Cursos visibles por contexto academico" ON public.courses
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR (
    status = 'active'
    AND career_id IN (select career_id from public.profiles where id = auth.uid())
    AND university_id IN (select university_id from public.profiles where id = auth.uid())
  )
);

DROP POLICY IF EXISTS "Usuario crea cursos en su carrera" ON public.courses;
DROP POLICY IF EXISTS "Usuario crea cursos en su carrera y ciclo" ON public.courses;
DROP POLICY IF EXISTS "Usuario crea cursos en su contexto academico" ON public.courses;
CREATE POLICY "Usuario crea cursos en su contexto academico" ON public.courses
FOR INSERT TO authenticated
WITH CHECK (
  public.is_active_user()
  AND created_by = auth.uid()
  AND university_id IN (select university_id from public.profiles where id = auth.uid())
  AND faculty_id IN (select faculty_id from public.profiles where id = auth.uid())
  AND career_id IN (select career_id from public.profiles where id = auth.uid())
);

-- Perfil actualizable por el alumno, incluyendo cambio de universidad/carrera/ciclo
DROP POLICY IF EXISTS "Usuario actualiza su propio perfil" ON public.profiles;
DROP POLICY IF EXISTS "Usuario actualiza datos basicos" ON public.profiles;
CREATE POLICY "Usuario actualiza su propio perfil"
ON public.profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Historial académico
DROP POLICY IF EXISTS "Usuario ve su historial academico" ON public.profile_academic_history;
CREATE POLICY "Usuario ve su historial academico" ON public.profile_academic_history
FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Usuario o admin registra historial academico" ON public.profile_academic_history;
CREATE POLICY "Usuario o admin registra historial academico" ON public.profile_academic_history
FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Admin gestiona historial academico" ON public.profile_academic_history;
CREATE POLICY "Admin gestiona historial academico" ON public.profile_academic_history
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Plantillas
DROP POLICY IF EXISTS "Plantillas visibles activas" ON public.evaluation_templates;
CREATE POLICY "Plantillas visibles activas" ON public.evaluation_templates
FOR SELECT TO authenticated
USING (status = 'active' OR public.is_admin());
DROP POLICY IF EXISTS "Admin gestiona plantillas" ON public.evaluation_templates;
CREATE POLICY "Admin gestiona plantillas" ON public.evaluation_templates
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Componentes visibles por plantilla activa" ON public.evaluation_components;
CREATE POLICY "Componentes visibles por plantilla activa" ON public.evaluation_components
FOR SELECT TO authenticated
USING (
  status = 'active'
  and exists (
    select 1 from public.evaluation_templates et
    where et.id = evaluation_components.template_id
      and (et.status = 'active' or public.is_admin())
  )
);
DROP POLICY IF EXISTS "Admin gestiona componentes" ON public.evaluation_components;
CREATE POLICY "Admin gestiona componentes" ON public.evaluation_components
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Notas flexibles
DROP POLICY IF EXISTS "Usuario ve sus notas flexibles" ON public.student_evaluation_scores;
CREATE POLICY "Usuario ve sus notas flexibles" ON public.student_evaluation_scores
FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS "Usuario registra sus notas flexibles" ON public.student_evaluation_scores;
CREATE POLICY "Usuario registra sus notas flexibles" ON public.student_evaluation_scores
FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid() AND public.is_active_user());
DROP POLICY IF EXISTS "Usuario actualiza sus notas flexibles" ON public.student_evaluation_scores;
CREATE POLICY "Usuario actualiza sus notas flexibles" ON public.student_evaluation_scores
FOR UPDATE TO authenticated
USING (user_id = auth.uid() OR public.is_admin())
WITH CHECK (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS "Admin gestiona notas flexibles" ON public.student_evaluation_scores;
CREATE POLICY "Admin gestiona notas flexibles" ON public.student_evaluation_scores
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Actualiza políticas de student_courses para contexto multiuniversidad
DROP POLICY IF EXISTS "Usuario agrega cursos a su lista" ON public.student_courses;
CREATE POLICY "Usuario agrega cursos a su lista"
ON public.student_courses
FOR INSERT TO authenticated
WITH CHECK (
  public.is_active_user()
  AND user_id = auth.uid()
  AND course_id IN (
    select c.id from public.courses c
    join public.profiles p on p.id = auth.uid()
    where c.status = 'active'
      and c.university_id = p.university_id
      and c.career_id = p.career_id
  )
);

-- ============================================================
-- 8. Validación final
-- ============================================================

select
  u.code as universidad,
  f.name as facultad,
  c.name as carrera,
  c.status
from public.careers c
join public.faculties f on f.id = c.faculty_id
join public.universities u on u.id = f.university_id
order by u.code, f.name, c.name;


-- Admin/superadmin principal sin contexto académico obligatorio
insert into public.admin_emails (email)
select lower('oscar.miguel.huaman.cabrera@gmail.com')
where exists (select 1 from information_schema.tables where table_schema='public' and table_name='admin_emails')
  and not exists (
    select 1 from public.admin_emails
    where lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com')
  );

update public.profiles
set role = 'superadmin',
    status = 'active',
    university_id = null,
    faculty_id = null,
    career_id = null,
    current_cycle_id = null,
    has_seen_tutorial = true,
    updated_at = now()
where lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com');
