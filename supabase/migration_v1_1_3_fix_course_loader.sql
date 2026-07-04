-- ============================================================
-- MI NOTA FINAL v1.1.3
-- FIX CARGA DE CURSOS EN FRONTEND / VALIDACIÓN DE CONTEXTO
-- ============================================================
-- Esta migración no altera datos críticos. Refuerza RLS para que:
-- 1) superadmin/admin pueda ver todos los cursos;
-- 2) estudiantes vean cursos activos de su universidad/facultad/carrera;
-- 3) ciclos sean visibles para todos los usuarios autenticados.

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

alter table public.courses enable row level security;

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

alter table public.cycles enable row level security;
drop policy if exists "Ciclos visibles" on public.cycles;
drop policy if exists "Admin gestiona ciclos" on public.cycles;

create policy "Ciclos visibles"
on public.cycles
for select
to anon, authenticated
using (true);

create policy "Admin gestiona ciclos"
on public.cycles
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Validación útil: cursos activos por contexto.
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
where c.status = 'active'
group by u.code, f.name, ca.name, cy.name, cy.order_number
order by u.code, f.name, ca.name, cy.order_number;
