-- ============================================================
-- MI NOTA FINAL v1.1.4
-- FIX RELACIÓN EVALUATION_TEMPLATES + SELECTOR DE CALCULADORA
-- ============================================================
-- Esta migración refuerza RLS para que el frontend pueda cargar
-- cursos, plantillas y componentes configurables por universidad.
-- La corrección del error PGRST201 se aplica en frontend usando la
-- relación explícita:
-- evaluation_templates!courses_evaluation_template_id_fkey

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

-- ============================================================
-- Cursos visibles
-- ============================================================

alter table public.courses enable row level security;

drop policy if exists "Cursos visibles por carrera y ciclo" on public.courses;
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

-- ============================================================
-- Plantillas y componentes visibles para calculadora configurable
-- ============================================================

alter table public.evaluation_templates enable row level security;
alter table public.evaluation_components enable row level security;

drop policy if exists "Plantillas visibles activas" on public.evaluation_templates;
drop policy if exists "Admin gestiona plantillas" on public.evaluation_templates;

create policy "Plantillas visibles activas"
on public.evaluation_templates
for select
to anon, authenticated
using (
  status = 'active'
  or public.is_admin()
);

create policy "Admin gestiona plantillas"
on public.evaluation_templates
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Componentes visibles por plantilla activa" on public.evaluation_components;
drop policy if exists "Admin gestiona componentes" on public.evaluation_components;

create policy "Componentes visibles por plantilla activa"
on public.evaluation_components
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.evaluation_templates et
    where et.id = evaluation_components.template_id
      and (
        et.status = 'active'
        or public.is_admin()
      )
  )
);

create policy "Admin gestiona componentes"
on public.evaluation_components
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- ============================================================
-- Validación rápida de plantillas activas
-- ============================================================

select
  u.code as universidad,
  et.name as plantilla,
  round(coalesce(sum(ec.weight_percent), 0)::numeric, 2) as total_porcentaje,
  count(ec.id) as componentes
from public.evaluation_templates et
left join public.universities u on u.id = et.university_id
left join public.evaluation_components ec on ec.template_id = et.id and ec.status = 'active'
where et.status = 'active'
group by u.code, et.name
order by u.code, et.name;
