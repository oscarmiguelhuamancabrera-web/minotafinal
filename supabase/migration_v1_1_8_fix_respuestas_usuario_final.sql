-- Mi Nota Final v1.1.8 - FIX FINAL respuestas de sugerencias visibles para alumnos
-- Ejecutar este script como ÚLTIMO script en Supabase.

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

-- Asegura columnas usadas por la respuesta del administrador en bases existentes.
alter table public.user_suggestions
  add column if not exists admin_response text,
  add column if not exists responded_by uuid references public.profiles(id) on delete set null,
  add column if not exists responded_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists user_suggestions_user_updated_idx
on public.user_suggestions(user_id, updated_at desc, created_at desc);
