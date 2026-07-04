-- Mi Nota Final v1.1.8
-- Centro de comunicación: anuncios administrables y sugerencias con respuesta del administrador.

create extension if not exists "pgcrypto";

-- 1. Anuncios / novedades publicados por admin/superadmin
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text not null,
  content text,
  type text not null default 'info' check (type in ('update','important','maintenance','reminder','info')),
  display_mode text not null default 'card' check (display_mode in ('banner','modal','card')),
  priority text not null default 'normal' check (priority in ('low','normal','high')),
  status text not null default 'active' check (status in ('draft','active','inactive')),
  target_role text not null default 'student' check (target_role in ('all','student','admin','superadmin')),
  university_id uuid references public.universities(id) on delete set null,
  faculty_id uuid references public.faculties(id) on delete set null,
  career_id uuid references public.careers(id) on delete set null,
  cycle_id uuid references public.cycles(id) on delete set null,
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists announcements_status_idx on public.announcements(status);
create index if not exists announcements_dates_idx on public.announcements(starts_at, ends_at);
create index if not exists announcements_context_idx on public.announcements(university_id, faculty_id, career_id, cycle_id);
create index if not exists announcements_created_idx on public.announcements(created_at desc);

-- 2. Lectura/cierre de anuncios por usuario
create table if not exists public.announcement_reads (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  seen_at timestamptz,
  dismissed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (announcement_id, user_id)
);

create index if not exists announcement_reads_user_idx on public.announcement_reads(user_id);
create index if not exists announcement_reads_announcement_idx on public.announcement_reads(announcement_id);

-- 3. Sugerencias / reportes de usuarios y respuesta del administrador
create table if not exists public.user_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'suggestion' check (type in ('suggestion','bug','missing_course','wrong_course','formula','profile','other')),
  subject text not null,
  message text not null,
  status text not null default 'pending' check (status in ('pending','reviewing','resolved','rejected')),
  admin_response text,
  responded_by uuid references public.profiles(id) on delete set null,
  responded_at timestamptz,
  university_id uuid references public.universities(id) on delete set null,
  faculty_id uuid references public.faculties(id) on delete set null,
  career_id uuid references public.careers(id) on delete set null,
  cycle_id uuid references public.cycles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_suggestions_user_idx on public.user_suggestions(user_id);
create index if not exists user_suggestions_status_idx on public.user_suggestions(status);
create index if not exists user_suggestions_context_idx on public.user_suggestions(university_id, faculty_id, career_id, cycle_id);
create index if not exists user_suggestions_created_idx on public.user_suggestions(created_at desc);

alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.user_suggestions enable row level security;

-- Anuncios: admin gestiona todo; usuarios autenticados leen anuncios activos.
drop policy if exists "Admin gestiona anuncios" on public.announcements;
create policy "Admin gestiona anuncios"
on public.announcements
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Usuarios leen anuncios activos" on public.announcements;
create policy "Usuarios leen anuncios activos"
on public.announcements
for select
to authenticated
using (
  status = 'active'
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at >= now())
);

-- Lecturas de anuncio: cada usuario maneja las suyas; admin puede consultar todo.
drop policy if exists "Usuario gestiona lectura de anuncios" on public.announcement_reads;
create policy "Usuario gestiona lectura de anuncios"
on public.announcement_reads
for all
to authenticated
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

-- Sugerencias: usuario crea y lee las suyas; admin lee y responde todas.
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
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Admin responde sugerencias" on public.user_suggestions;
create policy "Admin responde sugerencias"
on public.user_suggestions
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Evento de uso sugerido para analítica: suggestion_submitted se inserta desde la app en app_usage_events.
