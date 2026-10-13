-- PROPUESTA NO EJECUTADA: aceptación versionada de documentos legales.
-- Aplicar únicamente después de confirmar responsable legal, versiones y estrategia
-- de comunicación a usuarios existentes.

create table if not exists public.legal_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  terms_version text not null,
  terms_accepted_at timestamptz not null default now(),
  privacy_version text,
  privacy_accepted_at timestamptz,
  source text not null default 'web',
  created_at timestamptz not null default now(),
  unique (user_id, terms_version, privacy_version)
);

alter table public.legal_consents enable row level security;

create policy "Usuario consulta sus consentimientos o admin consulta todo"
  on public.legal_consents for select
  using (user_id = auth.uid() or public.is_admin());

create policy "Usuario registra su consentimiento"
  on public.legal_consents for insert
  with check (user_id = auth.uid() and public.is_active_user());

-- Reversión (ejecutar solo si se decide retirar esta propuesta):
-- drop table if exists public.legal_consents;
