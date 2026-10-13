-- Diagnóstico SOLO LECTURA para estadísticas de actividad en America/Lima.
-- No modifica tablas, vistas, funciones ni registros.

-- 1) Tipos de fecha usados por las tablas de actividad.
select table_schema, table_name, column_name, data_type, udt_name
from information_schema.columns
where table_schema = 'public'
  and table_name in ('login_activity', 'app_usage_events', 'admin_user_activity_summary')
  and column_name in ('login_at', 'login_date', 'created_at', 'updated_at')
order by table_name, ordinal_position;

-- 2) Definiciones de vistas y funciones relacionadas con actividad.
select table_schema, table_name, view_definition
from information_schema.views
where table_schema = 'public'
  and table_name ilike '%activity%';

select routine_schema, routine_name, routine_type, data_type, routine_definition
from information_schema.routines
where routine_schema = 'public'
  and (routine_name ilike '%activity%' or routine_name ilike '%login%');

-- 3) Límites del día actual de Perú convertidos al instante UTC.
with lima_day as (
  select (now() at time zone 'America/Lima')::date as day_in_lima
)
select
  day_in_lima,
  (day_in_lima::timestamp at time zone 'America/Lima') as start_instant,
  ((day_in_lima + 1)::timestamp at time zone 'America/Lima') as end_instant_exclusive,
  now() as database_now,
  now() at time zone 'America/Lima' as lima_now
from lima_day;

-- 4) Comparación de registros del día de Lima usando login_at.
with lima_day as (
  select (now() at time zone 'America/Lima')::date as day_in_lima
), bounds as (
  select
    (day_in_lima::timestamp at time zone 'America/Lima') as start_instant,
    ((day_in_lima + 1)::timestamp at time zone 'America/Lima') as end_instant_exclusive
  from lima_day
)
select count(*) as login_events_today_lima
from public.login_activity login
cross join bounds
where login.login_at >= bounds.start_instant
  and login.login_at < bounds.end_instant_exclusive;

-- 5) Eventos de uso del día de Lima.
with lima_day as (
  select (now() at time zone 'America/Lima')::date as day_in_lima
), bounds as (
  select
    (day_in_lima::timestamp at time zone 'America/Lima') as start_instant,
    ((day_in_lima + 1)::timestamp at time zone 'America/Lima') as end_instant_exclusive
  from lima_day
)
select count(*) as usage_events_today_lima
from public.app_usage_events event
cross join bounds
where event.created_at >= bounds.start_instant
  and event.created_at < bounds.end_instant_exclusive;

-- 6) Registros alrededor de las 19:00 de Lima para validar el corte UTC.
select id, user_id, login_at, login_date
from public.login_activity
where login_at >= now() - interval '2 days'
  and login_at < now()
order by login_at desc
limit 100;
