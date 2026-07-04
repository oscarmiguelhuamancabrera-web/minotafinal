-- ============================================================
-- MI NOTA FINAL v1.1.2
-- FIX GOOGLE NAMES + ADMIN COURSES + MULTIUNIVERSIDAD COURSES
-- Ejecutar después de v1.1.0 y v1.1.1
-- ============================================================

create extension if not exists "pgcrypto";

-- ============================================================
-- 1. FUNCIÓN ADMIN / SUPERADMIN
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and coalesce(p.role, '') in ('admin', 'superadmin')
  );
$$;

insert into public.admin_emails (email)
select lower('oscar.miguel.huaman.cabrera@gmail.com')
where not exists (
  select 1
  from public.admin_emails
  where lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com')
);

update public.profiles
set
  role = 'superadmin',
  status = 'active',
  university_id = null,
  faculty_id = null,
  career_id = null,
  current_cycle_id = null,
  updated_at = now()
where lower(email) = lower('oscar.miguel.huaman.cabrera@gmail.com');

-- ============================================================
-- 2. CORREGIR FULL_NAME / NAME DUPLICADO EN AUTH.USERS
-- Ejemplos:
-- Oscar Oscar Huaman Cabrera -> Oscar Huaman Cabrera
-- Raimond Raimond Paucar -> Raimond Paucar
-- ============================================================

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
    raw_user_meta_data,
    full_name,
    case
      when array_length(partes, 1) >= 2
       and lower(partes[1]) = lower(partes[2])
      then array_to_string(partes[2:array_length(partes, 1)], ' ')
      else full_name
    end as nuevo_full_name
  from separado
)
update auth.users u
set raw_user_meta_data =
  jsonb_set(
    jsonb_set(
      coalesce(u.raw_user_meta_data, '{}'::jsonb),
      '{full_name}',
      to_jsonb(c.nuevo_full_name),
      true
    ),
    '{name}',
    to_jsonb(c.nuevo_full_name),
    true
  )
from corregido c
where u.id = c.id
  and c.full_name <> c.nuevo_full_name;

-- ============================================================
-- 3. CORREGIR FIRST_NAME / LAST_NAME EN PROFILES
-- Regla:
-- 2 palabras: 1 nombre + 1 apellido
-- 3 palabras: 1 nombre + 2 apellidos
-- 4+ palabras: 2 nombres + apellidos restantes
-- ============================================================

with usuarios as (
  select
    p.id,
    trim(coalesce(
      u.raw_user_meta_data->>'full_name',
      u.raw_user_meta_data->>'name',
      trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, ''))
    )) as raw_full_name
  from public.profiles p
  left join auth.users u on u.id = p.id
), deduplicado as (
  select
    id,
    case
      when array_length(regexp_split_to_array(raw_full_name, '\s+'), 1) >= 2
       and lower((regexp_split_to_array(raw_full_name, '\s+'))[1]) = lower((regexp_split_to_array(raw_full_name, '\s+'))[2])
      then array_to_string((regexp_split_to_array(raw_full_name, '\s+'))[2:array_length(regexp_split_to_array(raw_full_name, '\s+'), 1)], ' ')
      else raw_full_name
    end as full_name
  from usuarios
  where raw_full_name is not null
    and trim(raw_full_name) <> ''
), separado as (
  select
    id,
    full_name,
    regexp_split_to_array(full_name, '\s+') as partes
  from deduplicado
), datos as (
  select
    id,
    case
      when array_length(partes, 1) = 1 then partes[1]
      when array_length(partes, 1) = 2 then partes[1]
      when array_length(partes, 1) = 3 then partes[1]
      when array_length(partes, 1) >= 4 then partes[1] || ' ' || partes[2]
      else partes[1]
    end as nuevo_first_name,
    case
      when array_length(partes, 1) = 1 then ''
      when array_length(partes, 1) = 2 then partes[2]
      when array_length(partes, 1) = 3 then partes[2] || ' ' || partes[3]
      when array_length(partes, 1) >= 4 then array_to_string(partes[3:array_length(partes, 1)], ' ')
      else ''
    end as nuevo_last_name
  from separado
)
update public.profiles p
set
  first_name = d.nuevo_first_name,
  last_name = d.nuevo_last_name,
  full_name = trim(d.nuevo_first_name || ' ' || d.nuevo_last_name),
  updated_at = now()
from datos d
where p.id = d.id
  and coalesce(p.role, '') not in ('admin', 'superadmin');

-- ============================================================
-- 4. RLS PARA CATÁLOGOS Y CURSOS
-- Admin/superadmin debe ver todo.
-- Alumno solo ve cursos activos de su contexto académico.
-- ============================================================

alter table public.universities enable row level security;
alter table public.faculties enable row level security;
alter table public.careers enable row level security;
alter table public.cycles enable row level security;
alter table public.courses enable row level security;
alter table public.profile_academic_history enable row level security;

-- UNIVERSIDADES
drop policy if exists "Catalogo universidades activo" on public.universities;
drop policy if exists "Admin gestiona universidades" on public.universities;

create policy "Catalogo universidades activo"
on public.universities
for select
to anon, authenticated
using (status = 'active' or public.is_admin());

create policy "Admin gestiona universidades"
on public.universities
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- FACULTADES
drop policy if exists "Catalogo facultades activo" on public.faculties;
drop policy if exists "Admin gestiona facultades" on public.faculties;

create policy "Catalogo facultades activo"
on public.faculties
for select
to anon, authenticated
using (status = 'active' or public.is_admin());

create policy "Admin gestiona facultades"
on public.faculties
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- CARRERAS
drop policy if exists "Catalogo carreras activo" on public.careers;
drop policy if exists "Admin gestiona carreras" on public.careers;
drop policy if exists "Carreras visibles" on public.careers;
drop policy if exists "Careers visible" on public.careers;

create policy "Catalogo carreras activo"
on public.careers
for select
to anon, authenticated
using (status = 'active' or public.is_admin());

create policy "Admin gestiona carreras"
on public.careers
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- CICLOS
drop policy if exists "Ciclos visibles" on public.cycles;
drop policy if exists "Admin gestiona ciclos" on public.cycles;

create policy "Ciclos visibles"
on public.cycles
for select
to anon, authenticated
using (status = 'active' or public.is_admin());

create policy "Admin gestiona ciclos"
on public.cycles
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- CURSOS
drop policy if exists "Cursos visibles por carrera y ciclo" on public.courses;
drop policy if exists "Usuario crea cursos por carrera y ciclo" on public.courses;
drop policy if exists "Admin actualiza cursos por carrera y ciclo" on public.courses;
drop policy if exists "Cursos visibles multiuniversidad" on public.courses;
drop policy if exists "Admin gestiona cursos multiuniversidad" on public.courses;
drop policy if exists "Usuario crea cursos multiuniversidad" on public.courses;

create policy "Cursos visibles multiuniversidad"
on public.courses
for select
to authenticated
using (
  public.is_admin()
  or (
    status = 'active'
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.university_id = courses.university_id
        and p.faculty_id = courses.faculty_id
        and p.career_id = courses.career_id
    )
  )
);

create policy "Admin gestiona cursos multiuniversidad"
on public.courses
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Usuario crea cursos multiuniversidad"
on public.courses
for insert
to authenticated
with check (
  created_by = auth.uid()
  and status = 'active'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.university_id = courses.university_id
      and p.faculty_id = courses.faculty_id
      and p.career_id = courses.career_id
  )
);

-- HISTORIAL ACADÉMICO
drop policy if exists "Usuario o admin registra historial academico" on public.profile_academic_history;
drop policy if exists "Usuario ve su historial academico" on public.profile_academic_history;
drop policy if exists "Admin gestiona historial academico" on public.profile_academic_history;

create policy "Usuario o admin registra historial academico"
on public.profile_academic_history
for insert
to authenticated
with check (user_id = auth.uid() or public.is_admin());

create policy "Usuario ve su historial academico"
on public.profile_academic_history
for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy "Admin gestiona historial academico"
on public.profile_academic_history
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- ============================================================
-- 5. REASIGNAR / INSERTAR MALLA UPSJB INGENIERÍA DE SISTEMAS
-- Corrige cursos sin university_id/faculty_id o vinculados a carrera antigua.
-- ============================================================

alter table public.courses add column if not exists university_id uuid references public.universities(id);
alter table public.courses add column if not exists faculty_id uuid references public.faculties(id);
alter table public.courses add column if not exists evaluation_template_id uuid references public.evaluation_templates(id);

-- Quitar índice durante saneamiento para evitar bloqueos por duplicados temporales.
drop index if exists public.courses_context_cycle_name_unique;

with ctx as (
  select
    u.id as university_id,
    f.id as faculty_id,
    c.id as career_id,
    et.id as template_id
  from public.universities u
  join public.faculties f on f.university_id = u.id
  join public.careers c on c.faculty_id = f.id
  left join public.evaluation_templates et
    on et.university_id = u.id
   and lower(trim(et.name)) = lower('UPSJB - Evaluación estándar')
  where lower(trim(u.code)) = lower('UPSJB')
    and lower(trim(f.name)) = lower('Facultad de Ingenierías')
    and lower(trim(c.name)) = lower('Ingeniería de Sistemas')
    and c.status = 'active'
  limit 1
), sistemas_careers as (
  select id
  from public.careers
  where lower(trim(name)) = lower('Ingeniería de Sistemas')
), course_names(name) as (
  values
  ('Introducción a la Ingeniería de Sistemas'),
  ('Geometría Analítica y Álgebra Lineal'),
  ('Creatividad Digital'),
  ('Química'),
  ('Lógico-Matemática'),
  ('Redacción e Interpretación de Textos'),
  ('Vida Universitaria y Gestión del Conocimiento'),
  ('Algorítmica'),
  ('Física I'),
  ('Comunicación y Medios Digitales'),
  ('Realidad Nacional'),
  ('Filosofía'),
  ('Inglés I'),
  ('Cálculo Diferencial'),
  ('Programación Orientado a Objetos'),
  ('Física II'),
  ('Estática'),
  ('Cálculo Integral'),
  ('Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Interculturalidad'),
  ('Inglés II'),
  ('Ingeniería de Software'),
  ('Modelamiento de Base de Datos'),
  ('Taller de Programación Web'),
  ('Cálculo Numérico'),
  ('Estadística Básica I'),
  ('Ciudadanía Global y Desarrollo Sostenible'),
  ('Sistemas Operativos'),
  ('Modelamiento de Procesos'),
  ('Contabilidad y Finanzas'),
  ('Estadística Básica II'),
  ('Desarrollo de Aplicaciones Móviles'),
  ('Matemática Computacional'),
  ('Administración de Base de Datos'),
  ('Circuitos y Sistemas Electrónicos'),
  ('Redes y Comunicaciones'),
  ('Costos y Presupuestos'),
  ('Computación Gráfica y Visual'),
  ('Desarrollo de Sistemas Multiplataforma'),
  ('Teoría General de Sistemas'),
  ('Metodología de la Investigación Científica'),
  ('Investigación de Operaciones'),
  ('Sistemas Inteligentes'),
  ('Arquitectura y Sistemas Embebidos'),
  ('Arquitectura Empresarial y Planeamiento Estratégico'),
  ('Dinámica de Sistemas'),
  ('Optimización y Simulación de Sistemas'),
  ('Electivo'),
  ('Arquitectura de Software'),
  ('Big Data y Analytics'),
  ('Metodologías Ágiles'),
  ('Telecomunicaciones y Sistemas Distribuidos'),
  ('Redacción Científica'),
  ('Ética y Profesionalismo'),
  ('Calidad y Pruebas de Software'),
  ('Sistemas de Soporte de Decisiones'),
  ('Gestión de Proyectos'),
  ('Inteligencia Artificial'),
  ('Trabajo de Investigación I'),
  ('Seguridad de la Información y Auditoría de Sistemas'),
  ('Internet de las Cosas y Robótica'),
  ('Redacción y Publicación de Artículos Científicos'),
  ('Trabajo de Investigación II'),
  ('Prácticas Preprofesionales')
)
update public.courses co
set
  university_id = ctx.university_id,
  faculty_id = ctx.faculty_id,
  career_id = ctx.career_id,
  evaluation_template_id = coalesce(co.evaluation_template_id, ctx.template_id),
  status = 'active',
  updated_at = now()
from ctx, course_names cn
where lower(trim(co.name)) = lower(trim(cn.name))
  and (
    co.career_id in (select id from sistemas_careers)
    or co.university_id is null
    or co.faculty_id is null
    or co.career_id is null
  );

with ctx as (
  select
    u.id as university_id,
    f.id as faculty_id,
    c.id as career_id,
    et.id as template_id
  from public.universities u
  join public.faculties f on f.university_id = u.id
  join public.careers c on c.faculty_id = f.id
  left join public.evaluation_templates et
    on et.university_id = u.id
   and lower(trim(et.name)) = lower('UPSJB - Evaluación estándar')
  where lower(trim(u.code)) = lower('UPSJB')
    and lower(trim(f.name)) = lower('Facultad de Ingenierías')
    and lower(trim(c.name)) = lower('Ingeniería de Sistemas')
    and c.status = 'active'
  limit 1
), course_data(cycle_number, course_name) as (
  values
  (1, 'Introducción a la Ingeniería de Sistemas'),
  (1, 'Geometría Analítica y Álgebra Lineal'),
  (1, 'Creatividad Digital'),
  (1, 'Química'),
  (1, 'Lógico-Matemática'),
  (1, 'Redacción e Interpretación de Textos'),
  (1, 'Vida Universitaria y Gestión del Conocimiento'),
  (2, 'Algorítmica'),
  (2, 'Física I'),
  (2, 'Comunicación y Medios Digitales'),
  (2, 'Realidad Nacional'),
  (2, 'Filosofía'),
  (2, 'Inglés I'),
  (2, 'Cálculo Diferencial'),
  (3, 'Programación Orientado a Objetos'),
  (3, 'Física II'),
  (3, 'Estática'),
  (3, 'Cálculo Integral'),
  (3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  (3, 'Interculturalidad'),
  (3, 'Inglés II'),
  (4, 'Ingeniería de Software'),
  (4, 'Modelamiento de Base de Datos'),
  (4, 'Taller de Programación Web'),
  (4, 'Cálculo Numérico'),
  (4, 'Estadística Básica I'),
  (4, 'Ciudadanía Global y Desarrollo Sostenible'),
  (5, 'Sistemas Operativos'),
  (5, 'Modelamiento de Procesos'),
  (5, 'Contabilidad y Finanzas'),
  (5, 'Estadística Básica II'),
  (5, 'Desarrollo de Aplicaciones Móviles'),
  (5, 'Matemática Computacional'),
  (5, 'Administración de Base de Datos'),
  (6, 'Circuitos y Sistemas Electrónicos'),
  (6, 'Redes y Comunicaciones'),
  (6, 'Costos y Presupuestos'),
  (6, 'Computación Gráfica y Visual'),
  (6, 'Desarrollo de Sistemas Multiplataforma'),
  (6, 'Teoría General de Sistemas'),
  (6, 'Metodología de la Investigación Científica'),
  (7, 'Investigación de Operaciones'),
  (7, 'Sistemas Inteligentes'),
  (7, 'Arquitectura y Sistemas Embebidos'),
  (7, 'Arquitectura Empresarial y Planeamiento Estratégico'),
  (7, 'Dinámica de Sistemas'),
  (7, 'Optimización y Simulación de Sistemas'),
  (7, 'Electivo'),
  (8, 'Arquitectura de Software'),
  (8, 'Big Data y Analytics'),
  (8, 'Metodologías Ágiles'),
  (8, 'Telecomunicaciones y Sistemas Distribuidos'),
  (8, 'Redacción Científica'),
  (8, 'Ética y Profesionalismo'),
  (8, 'Electivo'),
  (9, 'Calidad y Pruebas de Software'),
  (9, 'Sistemas de Soporte de Decisiones'),
  (9, 'Gestión de Proyectos'),
  (9, 'Inteligencia Artificial'),
  (9, 'Trabajo de Investigación I'),
  (9, 'Electivo'),
  (10, 'Seguridad de la Información y Auditoría de Sistemas'),
  (10, 'Internet de las Cosas y Robótica'),
  (10, 'Redacción y Publicación de Artículos Científicos'),
  (10, 'Trabajo de Investigación II'),
  (10, 'Prácticas Preprofesionales'),
  (10, 'Electivo')
)
insert into public.courses (
  university_id,
  faculty_id,
  career_id,
  cycle_id,
  name,
  created_by,
  status,
  evaluation_template_id,
  created_at,
  updated_at
)
select
  ctx.university_id,
  ctx.faculty_id,
  ctx.career_id,
  cy.id,
  cd.course_name,
  null,
  'active',
  ctx.template_id,
  now(),
  now()
from course_data cd
cross join ctx
join public.cycles cy on cy.order_number = cd.cycle_number
where not exists (
  select 1
  from public.courses c
  where c.university_id = ctx.university_id
    and c.faculty_id = ctx.faculty_id
    and c.career_id = ctx.career_id
    and c.cycle_id = cy.id
    and lower(trim(c.name)) = lower(trim(cd.course_name))
    and c.status = 'active'
);

-- Desactivar duplicados activos dentro del mismo contexto.
with ranked as (
  select
    id,
    row_number() over (
      partition by university_id, faculty_id, career_id, cycle_id, lower(trim(name))
      order by created_at asc nulls last, id asc
    ) as rn
  from public.courses
  where status = 'active'
    and university_id is not null
    and faculty_id is not null
    and career_id is not null
    and cycle_id is not null
), duplicates as (
  select id from ranked where rn > 1
)
update public.courses c
set
  status = 'inactive',
  name = c.name || ' (duplicado inactivo)',
  updated_at = now()
from duplicates d
where c.id = d.id;

create unique index if not exists courses_context_cycle_name_unique
on public.courses (
  university_id,
  faculty_id,
  career_id,
  cycle_id,
  lower(trim(name))
)
where status = 'active';

-- Sincronizar contexto de Mis cursos del alumno con el curso real.
update public.student_courses sc
set
  university_id = c.university_id,
  faculty_id = c.faculty_id,
  career_id = c.career_id,
  cycle_id = c.cycle_id,
  updated_at = now()
from public.courses c
where sc.course_id = c.id
  and (
    sc.university_id is distinct from c.university_id
    or sc.faculty_id is distinct from c.faculty_id
    or sc.career_id is distinct from c.career_id
    or sc.cycle_id is distinct from c.cycle_id
  );

-- ============================================================
-- 6. VALIDACIONES ÚTILES
-- ============================================================

select
  u.code as universidad,
  f.name as facultad,
  ca.name as carrera,
  cy.name as ciclo,
  count(c.id) as total_cursos
from public.courses c
join public.universities u on u.id = c.university_id
join public.faculties f on f.id = c.faculty_id
join public.careers ca on ca.id = c.career_id
join public.cycles cy on cy.id = c.cycle_id
where lower(u.code) = lower('UPSJB')
  and lower(ca.name) = lower('Ingeniería de Sistemas')
  and c.status = 'active'
group by u.code, f.name, ca.name, cy.name, cy.order_number
order by cy.order_number;
