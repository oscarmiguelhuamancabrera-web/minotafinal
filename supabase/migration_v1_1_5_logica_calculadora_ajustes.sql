-- ============================================================
-- MI NOTA FINAL v1.1.5
-- LÓGICA DE CALCULADORA/AJUSTES POR UNIVERSIDAD
-- + CARGA MALLA UAI MEDICINA HUMANA
-- ============================================================

-- Esta migración es idempotente.
-- Refuerza las plantillas configurables y carga la malla de Medicina Humana UAI.

create extension if not exists "pgcrypto";

-- ============================================================
-- 1. Asegurar universidad, facultad y carrera UAI Medicina Humana
-- ============================================================

insert into public.universities (name, code, status)
select 'Universidad Autónoma de Ica', 'UAI', 'active'
where not exists (
  select 1 from public.universities where lower(trim(code)) = lower('UAI')
);

with u as (
  select id from public.universities where lower(trim(code)) = lower('UAI') limit 1
)
insert into public.faculties (university_id, name, status)
select u.id, 'Facultad de Ciencias de la Salud', 'active'
from u
where not exists (
  select 1
  from public.faculties f
  where f.university_id = u.id
    and lower(trim(f.name)) = lower('Facultad de Ciencias de la Salud')
);

with ctx as (
  select u.id as university_id, f.id as faculty_id
  from public.universities u
  join public.faculties f on f.university_id = u.id
  where lower(trim(u.code)) = lower('UAI')
    and lower(trim(f.name)) = lower('Facultad de Ciencias de la Salud')
  limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Medicina Humana', 'active', now(), now()
from ctx
where not exists (
  select 1
  from public.careers c
  where c.faculty_id = ctx.faculty_id
    and lower(trim(c.name)) = lower('Medicina Humana')
);

-- ============================================================
-- 2. Asegurar ciclos I al XIV
-- ============================================================

with data(name, order_number) as (
  values
  ('I ciclo', 1), ('II ciclo', 2), ('III ciclo', 3), ('IV ciclo', 4),
  ('V ciclo', 5), ('VI ciclo', 6), ('VII ciclo', 7), ('VIII ciclo', 8),
  ('IX ciclo', 9), ('X ciclo', 10), ('XI ciclo', 11), ('XII ciclo', 12),
  ('XIII ciclo', 13), ('XIV ciclo', 14)
)
insert into public.cycles (name, order_number)
select d.name, d.order_number
from data d
where not exists (
  select 1 from public.cycles cy where cy.order_number = d.order_number
);

-- ============================================================
-- 3. Asegurar plantilla UAI por unidades
-- ============================================================

with u as (
  select id from public.universities where lower(trim(code)) = lower('UAI') limit 1
)
insert into public.evaluation_templates (
  university_id,
  name,
  description,
  min_passing_grade,
  scale_min,
  scale_max,
  status,
  created_at,
  updated_at
)
select
  u.id,
  'UAI - Evaluación por unidades',
  'FK1, FK2 y evaluaciones sumativas por unidades',
  11,
  0,
  20,
  'draft',
  now(),
  now()
from u
where not exists (
  select 1
  from public.evaluation_templates et
  where et.university_id = u.id
    and lower(trim(et.name)) = lower('UAI - Evaluación por unidades')
);

with template as (
  select id
  from public.evaluation_templates
  where lower(trim(name)) = lower('UAI - Evaluación por unidades')
  limit 1
),
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
insert into public.evaluation_components (
  template_id,
  component_order,
  short_name,
  name,
  unit_name,
  weight_percent,
  status,
  created_at,
  updated_at
)
select
  t.id,
  d.component_order,
  d.short_name,
  d.name,
  d.unit_name,
  d.weight_percent,
  'active',
  now(),
  now()
from data d
cross join template t
where not exists (
  select 1
  from public.evaluation_components ec
  where ec.template_id = t.id
    and ec.component_order = d.component_order
);

update public.evaluation_templates
set status = 'active', updated_at = now()
where lower(trim(name)) = lower('UAI - Evaluación por unidades');

-- ============================================================
-- 4. Cargar malla curricular UAI Medicina Humana
-- ============================================================

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
   and lower(trim(et.name)) = lower('UAI - Evaluación por unidades')
  where lower(trim(u.code)) = lower('UAI')
    and lower(trim(f.name)) = lower('Facultad de Ciencias de la Salud')
    and lower(trim(c.name)) = lower('Medicina Humana')
  limit 1
),
course_data(cycle_number, course_name) as (
  values
  (1, 'Matemática I'),
  (1, 'Redacción y Comunicación'),
  (1, 'Métodos de estudio universitario'),
  (1, 'Filosofía y Ética'),
  (1, 'Introducción a la Medicina'),
  (1, 'Biología'),

  (2, 'Matemática II'),
  (2, 'Metodología de la Investigación'),
  (2, 'Realidad nacional y Globalización'),
  (2, 'Administración y emprendimiento'),
  (2, 'Cultura inclusiva'),
  (2, 'Cultura ambiental'),
  (2, 'Anatomía'),

  (3, 'Biología Celular'),
  (3, 'Biofísica'),
  (3, 'Química orgánica'),
  (3, 'Embriología y genética'),
  (3, 'Histología'),
  (3, 'Fisiología'),
  (3, 'Actividades de Proyección Social I'),

  (4, 'Inmunología'),
  (4, 'Bioquímica'),
  (4, 'Microbiología y parasitología'),
  (4, 'Aparato locomotor'),
  (4, 'Sistema tegumentario'),
  (4, 'Sistema endocrino'),
  (4, 'Actividades de Proyección Social II'),

  (5, 'Farmacología'),
  (5, 'Patología'),
  (5, 'Sistema digestivo'),
  (5, 'Sistema cardiovascular y linfático'),
  (5, 'Sistema respiratorio'),
  (5, 'Tecnología de información en salud'),
  (5, 'Actividades de Proyección Social III'),

  (6, 'Nutrición y metabolismo'),
  (6, 'Epidemiología Básica'),
  (6, 'Aparato excretor y reproductor'),
  (6, 'Sistema nervioso'),
  (6, 'Psicología médica'),
  (6, 'Inglés I'),

  (7, 'Estrategias sanitarias'),
  (7, 'Introducción a la clínica'),
  (7, 'Taller de Investigación I'),
  (7, 'Inglés II'),
  (7, 'Bioética'),
  (7, 'Epidemiología Clínica'),

  (8, 'Genética de la enfermedad'),
  (8, 'Clínica quirúrgica I'),
  (8, 'Clínica médica I'),
  (8, 'Inglés III'),
  (8, 'Taller de Investigación II'),
  (8, 'Clínica Pediátrica'),

  (9, 'Clínica quirúrgica II'),
  (9, 'Clínica médica II'),
  (9, 'Proyecto de tesis'),
  (9, 'Clínica Gineco obstetra I'),
  (9, 'Clínica de las especialidades pediátricas'),

  (10, 'Clínica Gineco obstetra II'),
  (10, 'Medicina legal'),
  (10, 'Desarrollo de tesis'),
  (10, 'Clínica Neurológica'),
  (10, 'Electivo'),

  (11, 'Externado de Cirugía'),
  (11, 'Externado de medicina'),
  (11, 'Electivo'),

  (12, 'Externado Ginecobstetra'),
  (12, 'Externado de pediatría'),
  (12, 'Electivo'),

  (13, 'Internado de Medicina'),
  (13, 'Internado de Cirugía'),

  (14, 'Internado de Pediatría'),
  (14, 'Internado Ginecobstetra')
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

-- ============================================================
-- 5. Validación final
-- ============================================================

select
  u.code as universidad,
  f.name as facultad,
  ca.name as carrera,
  cy.name as ciclo,
  cy.order_number,
  count(c.id) as total_cursos
from public.courses c
join public.universities u on u.id = c.university_id
join public.faculties f on f.id = c.faculty_id
join public.careers ca on ca.id = c.career_id
join public.cycles cy on cy.id = c.cycle_id
where lower(u.code) = lower('UAI')
  and lower(f.name) = lower('Facultad de Ciencias de la Salud')
  and lower(ca.name) = lower('Medicina Humana')
  and c.status = 'active'
group by u.code, f.name, ca.name, cy.name, cy.order_number
order by cy.order_number;
