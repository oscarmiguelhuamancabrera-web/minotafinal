-- ============================================================
-- MI NOTA FINAL v1.1.7
-- Mejoras admin, cursos por usuario, última conexión, uso real,
-- botón agregar todos los cursos del ciclo y estabilidad de navegación.
-- ============================================================

create extension if not exists "pgcrypto";

-- 1. Índices para que el panel admin cargue rápido.
create index if not exists student_courses_user_status_idx
on public.student_courses(user_id, status);

create index if not exists student_courses_context_idx
on public.student_courses(university_id, faculty_id, career_id, cycle_id);

create index if not exists calculation_history_user_created_idx
on public.calculation_history(user_id, created_at desc);

create index if not exists login_activity_user_login_idx
on public.login_activity(user_id, login_at desc);

create index if not exists app_usage_events_user_created_idx
on public.app_usage_events(user_id, created_at desc);

-- 2. Saneamiento adicional de nombres duplicados por Google.
-- Caso observado: first_name = 'Oscar', last_name = 'Oscar Huamán'.
update public.profiles p
set
  last_name = trim(substr(p.last_name, length(p.first_name) + 1)),
  full_name = trim(p.first_name || ' ' || trim(substr(p.last_name, length(p.first_name) + 1))),
  updated_at = now()
where coalesce(p.role, 'student') not in ('admin', 'superadmin')
  and p.first_name is not null
  and p.last_name is not null
  and lower(trim(p.last_name)) like lower(trim(p.first_name)) || ' %';

-- 3. Vista de apoyo para auditoría admin.
-- La app calcula estas métricas en frontend, pero esta vista permite validar desde SQL.
create or replace view public.admin_user_activity_summary as
select
  p.id as user_id,
  p.email,
  p.first_name,
  p.last_name,
  p.role,
  p.status,
  p.university_id,
  u.code as university_code,
  u.name as university_name,
  p.faculty_id,
  f.name as faculty_name,
  p.career_id,
  ca.name as career_name,
  p.current_cycle_id as cycle_id,
  cy.name as cycle_name,
  count(distinct sc.course_id) filter (where sc.status = 'visible') as courses_count,
  count(distinct ch.id) as calculations_count,
  max(la.login_at) as last_login_at,
  max(aue.created_at) as last_real_activity_at,
  case
    when max(la.login_at) is null then null
    else floor(extract(epoch from (now() - max(la.login_at))) / 86400)::int
  end as inactive_days,
  case
    when max(aue.created_at) is null then null
    else floor(extract(epoch from (now() - max(aue.created_at))) / 86400)::int
  end as real_inactive_days
from public.profiles p
left join public.universities u on u.id = p.university_id
left join public.faculties f on f.id = p.faculty_id
left join public.careers ca on ca.id = p.career_id
left join public.cycles cy on cy.id = p.current_cycle_id
left join public.student_courses sc on sc.user_id = p.id
left join public.calculation_history ch on ch.user_id = p.id
left join public.login_activity la on la.user_id = p.id
left join public.app_usage_events aue on aue.user_id = p.id
group by
  p.id,
  p.email,
  p.first_name,
  p.last_name,
  p.role,
  p.status,
  p.university_id,
  u.code,
  u.name,
  p.faculty_id,
  f.name,
  p.career_id,
  ca.name,
  p.current_cycle_id,
  cy.name;

-- 4. Permisos de lectura de la vista para usuarios autenticados.
-- La seguridad real se mantiene por RLS de las tablas base y por el frontend admin.
grant select on public.admin_user_activity_summary to authenticated;

select 'v1.1.7 listo: admin con cursos por usuario, última conexión, uso real y mejoras de cursos.' as resultado;
