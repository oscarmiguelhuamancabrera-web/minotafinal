-- Mi Nota Final v1.1.8 - FIX sugerencias visibles para admin/superadmin
-- Ejecutar después de migration_v1_1_8_anuncios_sugerencias.sql

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
      and coalesce(p.status, 'active') = 'active'
  );
$$;

alter table public.user_suggestions enable row level security;

drop policy if exists "Usuario crea sugerencias" on public.user_suggestions;
create policy "Usuario crea sugerencias"
on public.user_suggestions
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Usuario lee sus sugerencias o admin todas" on public.user_suggestions;
create policy "Usuario lee sus sugerencias o admin todas"
on public.user_suggestions
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "Admin responde sugerencias" on public.user_suggestions;
create policy "Admin responde sugerencias"
on public.user_suggestions
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Validación rápida: debe devolver registros al entrar como superadmin desde la app.
-- select id, subject, status, created_at from public.user_suggestions order by created_at desc limit 10;
