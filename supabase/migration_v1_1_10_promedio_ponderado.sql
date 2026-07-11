-- ============================================================
-- MI NOTA FINAL v1.1.10
-- Promedio ponderado por creditos de los cursos agregados.
-- Ejecutar en Supabase > SQL Editor > New query > Run
-- ============================================================

alter table public.student_courses
  add column if not exists credits numeric(5,2) not null default 1;

update public.student_courses
set credits = 1
where credits is null or credits <= 0;

do $$
begin
  alter table public.student_courses
    add constraint student_courses_credits_check
    check (credits > 0 and credits <= 30);
exception
  when duplicate_object then
    null;
end $$;

select 'v1.1.10 listo: creditos por curso y promedio ponderado.' as resultado;
