-- Mi Nota Final v1.2.0
-- Preferencia de promedio ponderado confirmada por estudiante y ciclo.
-- Esta migración se prepara localmente y no se ejecuta contra producción.

create table if not exists public.student_weighted_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  cycle_id uuid not null references public.cycles(id) on delete restrict,
  enabled boolean not null default false,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, cycle_id)
);

create index if not exists student_weighted_preferences_user_cycle_idx
  on public.student_weighted_preferences(user_id, cycle_id);

drop trigger if exists set_student_weighted_preferences_updated_at on public.student_weighted_preferences;
create trigger set_student_weighted_preferences_updated_at
before update on public.student_weighted_preferences
for each row execute function public.set_updated_at();

alter table public.student_weighted_preferences enable row level security;

drop policy if exists "Usuario ve su preferencia de ponderado" on public.student_weighted_preferences;
create policy "Usuario ve su preferencia de ponderado"
on public.student_weighted_preferences
for select to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Usuario crea su preferencia de ponderado" on public.student_weighted_preferences;
create policy "Usuario crea su preferencia de ponderado"
on public.student_weighted_preferences
for insert to authenticated
with check (user_id = auth.uid() and public.is_active_user());

drop policy if exists "Usuario actualiza su preferencia de ponderado" on public.student_weighted_preferences;
create policy "Usuario actualiza su preferencia de ponderado"
on public.student_weighted_preferences
for update to authenticated
using (user_id = auth.uid() and public.is_active_user())
with check (user_id = auth.uid() and public.is_active_user());

drop policy if exists "Usuario elimina su preferencia de ponderado" on public.student_weighted_preferences;
create policy "Usuario elimina su preferencia de ponderado"
on public.student_weighted_preferences
for delete to authenticated
using (user_id = auth.uid() or public.is_admin());

-- Verificación manual posterior a la aplicación:
-- select user_id, cycle_id, enabled, confirmed_at
-- from public.student_weighted_preferences
-- order by updated_at desc;
