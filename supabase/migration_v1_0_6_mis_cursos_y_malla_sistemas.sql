-- ============================================================
-- MI NOTA FINAL WEB/PWA
-- MIGRACIÓN 1.0.6
-- Mis cursos actuales, cursos de diferentes ciclos, estados en español
-- y carga inicial de malla curricular de Ingeniería de Sistemas.
-- Ejecutar en Supabase > SQL Editor > New query > Run
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 1. Asegurar ciclos y carreras base
-- ============================================================

insert into public.careers (name) values
('Ingeniería de Sistemas'),
('Contabilidad'),
('Administración'),
('Derecho'),
('Enfermería'),
('Psicología')
on conflict (name) do nothing;

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

alter table public.courses
  add column if not exists cycle_id uuid references public.cycles(id);

update public.courses
set cycle_id = (select id from public.cycles where order_number = 1 limit 1)
where cycle_id is null;

do $$
begin
  alter table public.courses alter column cycle_id set not null;
exception when others then
  raise notice 'No se pudo marcar courses.cycle_id como NOT NULL: %', sqlerrm;
end $$;

-- La unicidad debe considerar carrera + ciclo + nombre.
drop index if exists public.courses_career_name_unique;
create unique index if not exists courses_career_cycle_name_unique
on public.courses (career_id, cycle_id, lower(trim(name)))
where status = 'active';

-- ============================================================
-- 2. Tabla: cursos actuales del estudiante
-- ============================================================

create table if not exists public.student_courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  enrollment_type text not null default 'regular'
    check (enrollment_type in ('regular', 'arrastrado', 'adelantado', 'electivo', 'otro')),
  credits numeric(5,2) not null default 1 check (credits > 0 and credits <= 30),
  status text not null default 'visible'
    check (status in ('visible', 'hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, course_id)
);

create index if not exists student_courses_user_idx on public.student_courses (user_id);
create index if not exists student_courses_course_idx on public.student_courses (course_id);
create index if not exists student_courses_type_idx on public.student_courses (enrollment_type);
create index if not exists student_courses_status_idx on public.student_courses (status);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_student_courses_updated_at on public.student_courses;
create trigger set_student_courses_updated_at
before update on public.student_courses
for each row execute function public.set_updated_at();

-- Migración inicial: agrega como visibles los cursos activos del ciclo actual
-- para usuarios que aún no tengan ningún curso seleccionado.
insert into public.student_courses (user_id, course_id, enrollment_type, status)
select p.id, c.id, 'regular', 'visible'
from public.profiles p
join public.courses c
  on c.career_id = p.career_id
 and c.cycle_id = p.current_cycle_id
 and c.status = 'active'
where p.role = 'student'
  and p.status = 'active'
  and p.career_id is not null
  and p.current_cycle_id is not null
  and not exists (
    select 1 from public.student_courses sc
    where sc.user_id = p.id
  )
on conflict (user_id, course_id) do nothing;

-- ============================================================
-- 3. RLS y políticas actualizadas
-- ============================================================

alter table public.student_courses enable row level security;
alter table public.courses enable row level security;

-- Cursos oficiales: ahora el estudiante puede ver cursos activos de toda su carrera,
-- no solo de su ciclo actual. Esto permite cursos arrastrados y adelantados.
drop policy if exists "Cursos visibles por carrera" on public.courses;
drop policy if exists "Cursos visibles por carrera y ciclo" on public.courses;
create policy "Cursos visibles por carrera"
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
  )
);

-- El usuario puede crear cursos dentro de su carrera y elegir cualquier ciclo activo.
drop policy if exists "Usuario crea cursos en su carrera" on public.courses;
drop policy if exists "Usuario crea cursos en su carrera y ciclo" on public.courses;
create policy "Usuario crea cursos en su carrera"
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
    select id
    from public.cycles
    where status = 'active'
  )
);

drop policy if exists "Admin actualiza cursos" on public.courses;
create policy "Admin actualiza cursos"
on public.courses
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Políticas para student_courses.
drop policy if exists "Usuario ve sus cursos actuales o admin ve todos" on public.student_courses;
create policy "Usuario ve sus cursos actuales o admin ve todos"
on public.student_courses
for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Usuario agrega cursos a su lista" on public.student_courses;
create policy "Usuario agrega cursos a su lista"
on public.student_courses
for insert
to authenticated
with check (
  public.is_active_user()
  and user_id = auth.uid()
  and course_id in (
    select c.id
    from public.courses c
    join public.profiles p on p.id = auth.uid()
    where c.status = 'active'
      and c.career_id = p.career_id
  )
);

drop policy if exists "Usuario actualiza sus cursos actuales" on public.student_courses;
create policy "Usuario actualiza sus cursos actuales"
on public.student_courses
for update
to authenticated
using (user_id = auth.uid() and public.is_active_user())
with check (user_id = auth.uid());

drop policy if exists "Admin gestiona cursos actuales" on public.student_courses;
create policy "Admin gestiona cursos actuales"
on public.student_courses
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- ============================================================
-- 4. Carga de cursos de Ingeniería de Sistemas por ciclo
-- Fuente: brochure/malla curricular del programa.
-- created_by = null para que la app muestre "Sistema".
-- ============================================================

with sistemas as (
  select id as career_id
  from public.careers
  where lower(name) = lower('Ingeniería de Sistemas')
  limit 1
),
course_data(cycle_number, course_name) as (
  values
  -- CICLO 01
  (1, 'Introducción a la Ingeniería de Sistemas'),
  (1, 'Geometría Analítica y Álgebra Lineal'),
  (1, 'Creatividad Digital'),
  (1, 'Química'),
  (1, 'Lógico-Matemática'),
  (1, 'Redacción e Interpretación de Textos'),
  (1, 'Vida Universitaria y Gestión del Conocimiento'),

  -- CICLO 02
  (2, 'Algorítmica'),
  (2, 'Física I'),
  (2, 'Comunicación y Medios Digitales'),
  (2, 'Realidad Nacional'),
  (2, 'Filosofía'),
  (2, 'Inglés I'),
  (2, 'Cálculo Diferencial'),

  -- CICLO 03
  (3, 'Programación Orientado a Objetos'),
  (3, 'Física II'),
  (3, 'Estática'),
  (3, 'Cálculo Integral'),
  (3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  (3, 'Interculturalidad'),
  (3, 'Inglés II'),

  -- CICLO 04
  (4, 'Ingeniería de Software'),
  (4, 'Modelamiento de Base de Datos'),
  (4, 'Taller de Programación Web'),
  (4, 'Cálculo Numérico'),
  (4, 'Estadística Básica I'),
  (4, 'Ciudadanía Global y Desarrollo Sostenible'),

  -- CICLO 05
  (5, 'Sistemas Operativos'),
  (5, 'Modelamiento de Procesos'),
  (5, 'Contabilidad y Finanzas'),
  (5, 'Estadística Básica II'),
  (5, 'Desarrollo de Aplicaciones Móviles'),
  (5, 'Matemática Computacional'),
  (5, 'Administración de Base de Datos'),

  -- CICLO 06
  (6, 'Circuitos y Sistemas Electrónicos'),
  (6, 'Redes y Comunicaciones'),
  (6, 'Costos y Presupuestos'),
  (6, 'Computación Gráfica y Visual'),
  (6, 'Desarrollo de Sistemas Multiplataforma'),
  (6, 'Teoría General de Sistemas'),
  (6, 'Metodología de la Investigación Científica'),

  -- CICLO 07
  (7, 'Investigación de Operaciones'),
  (7, 'Sistemas Inteligentes'),
  (7, 'Arquitectura y Sistemas Embebidos'),
  (7, 'Arquitectura Empresarial y Planeamiento Estratégico'),
  (7, 'Dinámica de Sistemas'),
  (7, 'Optimización y Simulación de Sistemas'),
  (7, 'Electivo'),

  -- CICLO 08
  (8, 'Arquitectura de Software'),
  (8, 'Big Data y Analytics'),
  (8, 'Metodologías Ágiles'),
  (8, 'Telecomunicaciones y Sistemas Distribuidos'),
  (8, 'Redacción Científica'),
  (8, 'Ética y Profesionalismo'),
  (8, 'Electivo'),

  -- CICLO 09
  (9, 'Calidad y Pruebas de Software'),
  (9, 'Sistemas de Soporte de Decisiones'),
  (9, 'Gestión de Proyectos'),
  (9, 'Inteligencia Artificial'),
  (9, 'Trabajo de Investigación I'),
  (9, 'Electivo'),

  -- CICLO 10
  (10, 'Seguridad de la Información y Auditoría de Sistemas'),
  (10, 'Internet de las Cosas y Robótica'),
  (10, 'Redacción y Publicación de Artículos Científicos'),
  (10, 'Trabajo de Investigación II'),
  (10, 'Prácticas Preprofesionales'),
  (10, 'Electivo')
)
insert into public.courses (
  career_id,
  cycle_id,
  name,
  created_by,
  status,
  created_at,
  updated_at
)
select
  s.career_id,
  cy.id as cycle_id,
  cd.course_name,
  null as created_by,
  'active' as status,
  now() as created_at,
  now() as updated_at
from course_data cd
cross join sistemas s
join public.cycles cy
  on cy.order_number = cd.cycle_number
where not exists (
  select 1
  from public.courses c
  where c.career_id = s.career_id
    and c.cycle_id = cy.id
    and lower(trim(c.name)) = lower(trim(cd.course_name))
);

-- Validación rápida.
select
  ca.name as carrera,
  cy.name as ciclo,
  cy.order_number,
  c.name as curso,
  c.status,
  case when c.created_by is null then 'Sistema' else 'Usuario/Admin' end as creado_por
from public.courses c
join public.careers ca on ca.id = c.career_id
join public.cycles cy on cy.id = c.cycle_id
where ca.name = 'Ingeniería de Sistemas'
order by cy.order_number, c.name;
