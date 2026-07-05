-- ============================================================
-- MI NOTA FINAL v1.1.9
-- Conserva universidad y facultad seleccionadas en el registro.
-- Ejecutar después de las migraciones anteriores.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_university uuid;
  selected_faculty uuid;
  selected_career uuid;
  selected_cycle uuid;
  new_role text;
  meta_first text;
  meta_last text;
  meta_full text;
begin
  selected_university := nullif(new.raw_user_meta_data ->> 'university_id', '')::uuid;
  selected_faculty := nullif(new.raw_user_meta_data ->> 'faculty_id', '')::uuid;
  selected_career := nullif(new.raw_user_meta_data ->> 'career_id', '')::uuid;
  selected_cycle := nullif(new.raw_user_meta_data ->> 'current_cycle_id', '')::uuid;
  meta_first := coalesce(new.raw_user_meta_data ->> 'first_name', '');
  meta_last := coalesce(new.raw_user_meta_data ->> 'last_name', '');
  meta_full := coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '');

  if meta_first = '' and meta_full <> '' then
    meta_first := split_part(meta_full, ' ', 1);
  end if;

  if meta_last = '' and meta_full <> '' then
    meta_last := regexp_replace(meta_full, '^\S+\s*', '');
  end if;

  if selected_cycle is null then
    selected_cycle := (
      select id
      from public.cycles
      where status = 'active'
      order by order_number
      limit 1
    );
  end if;

  if exists (
    select 1
    from public.admin_emails
    where lower(email) = lower(new.email)
  ) then
    new_role := 'admin';
    selected_university := null;
    selected_faculty := null;
    selected_career := null;
    selected_cycle := null;
  else
    new_role := 'student';
  end if;

  insert into public.profiles (
    id,
    full_name,
    first_name,
    last_name,
    email,
    university_id,
    faculty_id,
    career_id,
    current_cycle_id,
    role,
    status
  )
  values (
    new.id,
    trim(coalesce(meta_first, '') || ' ' || coalesce(meta_last, '')),
    coalesce(meta_first, ''),
    coalesce(meta_last, ''),
    new.email,
    selected_university,
    selected_faculty,
    selected_career,
    selected_cycle,
    new_role,
    'active'
  )
  on conflict (id) do update set
    email = excluded.email,
    university_id = coalesce(profiles.university_id, excluded.university_id),
    faculty_id = coalesce(profiles.faculty_id, excluded.faculty_id),
    career_id = coalesce(profiles.career_id, excluded.career_id),
    current_cycle_id = coalesce(profiles.current_cycle_id, excluded.current_cycle_id),
    role = excluded.role,
    updated_at = now();

  insert into public.user_settings (
    user_id,
    pc1_percent,
    pc2_percent,
    pc3_percent,
    pc4_percent,
    partial_percent,
    final_percent,
    minimum_grade
  )
  select
    new.id,
    pc1_percent,
    pc2_percent,
    pc3_percent,
    pc4_percent,
    partial_percent,
    final_percent,
    minimum_grade
  from public.system_defaults
  where id = true
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- Recupera datos académicos de registros existentes cuando Auth todavía
-- conserva los valores seleccionados y el perfil público quedó incompleto.
update public.profiles as p
set
  university_id = coalesce(
    p.university_id,
    nullif(u.raw_user_meta_data ->> 'university_id', '')::uuid
  ),
  faculty_id = coalesce(
    p.faculty_id,
    nullif(u.raw_user_meta_data ->> 'faculty_id', '')::uuid
  ),
  career_id = coalesce(
    p.career_id,
    nullif(u.raw_user_meta_data ->> 'career_id', '')::uuid
  ),
  current_cycle_id = coalesce(
    p.current_cycle_id,
    nullif(u.raw_user_meta_data ->> 'current_cycle_id', '')::uuid
  ),
  updated_at = now()
from auth.users as u
where u.id = p.id
  and coalesce(p.role, 'student') = 'student'
  and (
    p.university_id is null
    or p.faculty_id is null
    or p.career_id is null
    or p.current_cycle_id is null
  );

select 'v1.1.9 lista: el registro conserva universidad, facultad, carrera y ciclo.' as resultado;
