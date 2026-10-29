-- Mi Nota Final — actualización Supabase consolidada
-- Alcance: seguridad RLS, créditos confirmados, preferencias ponderadas por ciclo
-- y aislamiento de los históricos por ciclo.
-- Este archivo no incluye el gestor de temas ni crea tablas/buckets de temas.
-- Ejecutar una sola vez en Supabase SQL Editor. No usa comandos de psql.

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ================================================================
-- 1. Preflight: la base histórica debe existir y tener el contexto
--    multiuniversidad que consume la versión actual de la aplicación.
-- ================================================================

DO $$
DECLARE
  required_table text;
  required_tables constant text[] := ARRAY[
    'profiles', 'admin_emails', 'cycles', 'courses', 'student_courses',
    'course_grades', 'student_evaluation_scores', 'calculation_history'
  ];
  missing_tables text := '';
  missing_columns text := '';
BEGIN
  FOREACH required_table IN ARRAY required_tables LOOP
    IF to_regclass(format('public.%s', required_table)) IS NULL THEN
      missing_tables := missing_tables || CASE WHEN missing_tables = '' THEN '' ELSE ', ' END || required_table;
    END IF;
  END LOOP;
  IF missing_tables <> '' THEN
    RAISE EXCEPTION
      'Base incompatible: faltan tablas public.%; restaura/aplica la línea histórica en staging antes de usar este consolidado.',
      missing_tables;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' profiles.id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='email' AND data_type='text') THEN missing_columns := missing_columns || ' profiles.email(text);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='role' AND data_type='text') THEN missing_columns := missing_columns || ' profiles.role(text);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='status' AND data_type='text') THEN missing_columns := missing_columns || ' profiles.status(text);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='current_cycle_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' profiles.current_cycle_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='university_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' profiles.university_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='faculty_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' profiles.faculty_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='career_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' profiles.career_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_emails' AND column_name='email' AND data_type='text') THEN missing_columns := missing_columns || ' admin_emails.email(text);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cycles' AND column_name='id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' cycles.id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='courses' AND column_name='id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' courses.id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='courses' AND column_name='cycle_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' courses.cycle_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='courses' AND column_name='university_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' courses.university_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='courses' AND column_name='faculty_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' courses.faculty_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='courses' AND column_name='career_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' courses.career_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='courses' AND column_name='status' AND data_type='text') THEN missing_columns := missing_columns || ' courses.status(text);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='user_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_courses.user_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='course_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_courses.course_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='cycle_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_courses.cycle_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='university_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_courses.university_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='faculty_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_courses.faculty_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='career_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_courses.career_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='status' AND data_type='text') THEN missing_columns := missing_columns || ' student_courses.status(text);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='course_grades' AND column_name='user_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' course_grades.user_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='course_grades' AND column_name='course_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' course_grades.course_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_evaluation_scores' AND column_name='user_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_evaluation_scores.user_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_evaluation_scores' AND column_name='course_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' student_evaluation_scores.course_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='calculation_history' AND column_name='user_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' calculation_history.user_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='calculation_history' AND column_name='course_id' AND udt_name='uuid') THEN missing_columns := missing_columns || ' calculation_history.course_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='calculation_history' AND column_name='created_at' AND udt_name='timestamptz') THEN missing_columns := missing_columns || ' calculation_history.created_at(timestamptz);'; END IF;
  IF missing_columns <> '' THEN
    RAISE EXCEPTION 'Base incompatible; faltan columnas o tipos requeridos:%', missing_columns;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%superadmin%'
  ) THEN
    RAISE EXCEPTION 'Base incompatible: profiles.role no tiene un CHECK que permita superadmin; aplica primero la migracion multiuniversidad.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.courses WHERE cycle_id IS NULL) THEN
    RAISE EXCEPTION 'Base incompatible: existen cursos sin cycle_id; no se instalaron funciones ni triggers.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'courses'
      AND column_name = 'cycle_id' AND is_nullable <> 'NO'
  ) THEN
    RAISE EXCEPTION 'Base incompatible: courses.cycle_id debe ser NOT NULL para aislar historiales por ciclo.';
  END IF;
END $$;

-- La lista de administradores histórica solo tenía email. Se añade un estado
-- explícito para poder revocar una dirección sin borrar el registro.
ALTER TABLE public.admin_emails
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema='public' AND table_name='admin_emails'
               AND column_name='status' AND data_type <> 'text') THEN
    RAISE EXCEPTION 'admin_emails.status debe ser text.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conrelid='public.admin_emails'::regclass
                   AND conname='admin_emails_status_check') THEN
    ALTER TABLE public.admin_emails
      ADD CONSTRAINT admin_emails_status_check CHECK (status IN ('active','inactive'));
  END IF;
END $$;

-- Dependencias de las políticas, acotadas y SECURITY DEFINER.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'superadmin')
        AND COALESCE(p.status, 'active') = 'active'
    )
    OR EXISTS (
      SELECT 1 FROM public.admin_emails a
      WHERE a.status = 'active'
        AND NULLIF(trim(a.email), '') IS NOT NULL
        AND NULLIF(trim(COALESCE(auth.jwt()->>'email', '')), '') IS NOT NULL
        AND lower(trim(a.email)) = lower(trim(COALESCE(auth.jwt()->>'email', '')))
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND COALESCE(p.status, 'active') = 'active'
  );
$$;

-- ================================================================
-- 2. Créditos explícitos y preferencias ponderadas por ciclo.
-- ================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='credits' AND udt_name <> 'numeric') THEN
    RAISE EXCEPTION 'student_courses.credits existe con un tipo distinto de numeric.';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_courses' AND column_name='credits_confirmed_at' AND udt_name <> 'timestamptz') THEN
    RAISE EXCEPTION 'student_courses.credits_confirmed_at existe con un tipo distinto de timestamptz.';
  END IF;
END $$;

ALTER TABLE public.student_courses
  ADD COLUMN IF NOT EXISTS credits numeric(5,2) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS credits_confirmed_at timestamptz;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.student_courses WHERE credits IS NULL OR credits <= 0 OR credits > 30) THEN
    RAISE EXCEPTION 'Hay créditos nulos o fuera del rango 0 < credits <= 30; no se modificaron datos.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.student_courses'::regclass AND conname='student_courses_credits_check') THEN
    ALTER TABLE public.student_courses ADD CONSTRAINT student_courses_credits_check CHECK (credits > 0 AND credits <= 30);
  END IF;
END $$;

ALTER TABLE public.student_courses
  ALTER COLUMN credits SET DEFAULT 1,
  ALTER COLUMN credits SET NOT NULL;

CREATE TABLE IF NOT EXISTS public.student_weighted_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cycle_id uuid NOT NULL REFERENCES public.cycles(id) ON DELETE RESTRICT,
  enabled boolean NOT NULL DEFAULT false,
  confirmed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
DECLARE missing text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_weighted_preferences' AND column_name='id' AND udt_name='uuid') THEN missing := missing || ' id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_weighted_preferences' AND column_name='user_id' AND udt_name='uuid') THEN missing := missing || ' user_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_weighted_preferences' AND column_name='cycle_id' AND udt_name='uuid') THEN missing := missing || ' cycle_id(uuid);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_weighted_preferences' AND column_name='enabled' AND data_type='boolean') THEN missing := missing || ' enabled(boolean);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_weighted_preferences' AND column_name='confirmed_at' AND udt_name='timestamptz') THEN missing := missing || ' confirmed_at(timestamptz);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_weighted_preferences' AND column_name='created_at' AND udt_name='timestamptz') THEN missing := missing || ' created_at(timestamptz);'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='student_weighted_preferences' AND column_name='updated_at' AND udt_name='timestamptz') THEN missing := missing || ' updated_at(timestamptz);'; END IF;
  IF missing <> '' THEN RAISE EXCEPTION 'student_weighted_preferences incompatible:%', missing; END IF;
  IF EXISTS (SELECT 1 FROM public.student_weighted_preferences WHERE enabled AND confirmed_at IS NULL) THEN RAISE EXCEPTION 'Hay preferencias ponderadas activas sin confirmed_at; no se modificaron datos.'; END IF;
  IF EXISTS (SELECT 1 FROM public.student_weighted_preferences GROUP BY user_id, cycle_id HAVING count(*) > 1) THEN RAISE EXCEPTION 'Hay preferencias duplicadas por usuario/ciclo; no se creó el índice único.'; END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS student_weighted_preferences_user_cycle_uidx
  ON public.student_weighted_preferences(user_id, cycle_id);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.student_weighted_preferences'::regclass AND conname='student_weighted_preferences_confirmation_check') THEN
    ALTER TABLE public.student_weighted_preferences ADD CONSTRAINT student_weighted_preferences_confirmation_check CHECK (enabled = false OR confirmed_at IS NOT NULL);
  END IF;
END $$;

DROP TRIGGER IF EXISTS set_student_weighted_preferences_updated_at ON public.student_weighted_preferences;
CREATE TRIGGER set_student_weighted_preferences_updated_at
BEFORE UPDATE ON public.student_weighted_preferences
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.mn_validate_weighted_preference()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF COALESCE(auth.role(),'') IN ('service_role','supabase_admin') OR auth.uid() IS NULL OR public.is_admin() THEN RETURN NEW; END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'La preferencia no pertenece a la sesion actual.'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.status='active' AND p.current_cycle_id=NEW.cycle_id) THEN
      RAISE EXCEPTION 'La nueva preferencia debe corresponder al ciclo actual.';
    END IF;
  ELSIF NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.cycle_id IS DISTINCT FROM OLD.cycle_id THEN
    RAISE EXCEPTION 'Un alumno no puede mover una preferencia a otro usuario o ciclo.';
  END IF;
  IF NEW.enabled AND NEW.confirmed_at IS NULL THEN RAISE EXCEPTION 'No se puede activar sin confirmed_at.'; END IF;
  IF NEW.enabled AND EXISTS (SELECT 1 FROM public.student_courses sc
    WHERE sc.user_id=NEW.user_id AND sc.cycle_id=NEW.cycle_id AND sc.status='visible' AND sc.credits_confirmed_at IS NULL) THEN
    RAISE EXCEPTION 'Hay creditos del ciclo sin confirmacion.';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS mn_validate_weighted_preference ON public.student_weighted_preferences;
CREATE TRIGGER mn_validate_weighted_preference BEFORE INSERT OR UPDATE ON public.student_weighted_preferences
FOR EACH ROW EXECUTE FUNCTION public.mn_validate_weighted_preference();

-- El historial recibe el ciclo desde el curso, aunque el cliente omita la
-- columna. Los registros cuyo course_id ya sea NULL conservan su historial.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='calculation_history' AND column_name='cycle_id' AND udt_name <> 'uuid') THEN
    RAISE EXCEPTION 'calculation_history.cycle_id existe con un tipo distinto de uuid.';
  END IF;
END $$;
ALTER TABLE public.calculation_history ADD COLUMN IF NOT EXISTS cycle_id uuid;
DO $$
DECLARE fk record;
BEGIN
  IF EXISTS (SELECT 1 FROM public.calculation_history h JOIN public.courses c ON c.id=h.course_id
            WHERE h.cycle_id IS NOT NULL AND h.cycle_id IS DISTINCT FROM c.cycle_id) THEN
    RAISE EXCEPTION 'calculation_history tiene cycle_id distinto al ciclo de su curso.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.calculation_history WHERE course_id IS NULL AND cycle_id IS NOT NULL) THEN
    RAISE EXCEPTION 'calculation_history contiene historiales sin curso pero con cycle_id; no se modificaron datos.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.calculation_history h
    LEFT JOIN public.courses c ON c.id = h.course_id
    WHERE h.course_id IS NOT NULL AND c.id IS NULL
  ) THEN
    RAISE EXCEPTION 'calculation_history contiene course_id sin curso correspondiente; no se modificaron datos.';
  END IF;
  UPDATE public.calculation_history h SET cycle_id=c.cycle_id
  FROM public.courses c WHERE h.cycle_id IS NULL AND h.course_id=c.id;
  FOR fk IN
    SELECT c.conname, pg_get_constraintdef(c.oid) AS definition
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
    WHERE c.conrelid = 'public.calculation_history'::regclass
      AND c.contype = 'f'
      AND a.attname = 'cycle_id'
      AND c.confrelid = 'public.cycles'::regclass
  LOOP
    IF fk.conname <> 'calculation_history_cycle_id_fkey'
       OR position('ON DELETE RESTRICT' IN upper(fk.definition)) = 0 THEN
      EXECUTE format('ALTER TABLE public.calculation_history DROP CONSTRAINT %I', fk.conname);
    END IF;
  END LOOP;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='public.calculation_history'::regclass
      AND conname='calculation_history_cycle_id_fkey'
  ) THEN
    ALTER TABLE public.calculation_history ADD CONSTRAINT calculation_history_cycle_id_fkey
      FOREIGN KEY (cycle_id) REFERENCES public.cycles(id) ON DELETE RESTRICT;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS calculation_history_user_cycle_created_idx
  ON public.calculation_history(user_id,cycle_id,created_at DESC);

CREATE OR REPLACE FUNCTION public.mn_assign_calculation_cycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE expected_cycle uuid;
BEGIN
  IF NEW.course_id IS NULL THEN
    IF NEW.cycle_id IS NOT NULL THEN RAISE EXCEPTION 'Un historial sin curso no puede declarar ciclo.'; END IF;
    RETURN NEW;
  END IF;
  SELECT cycle_id INTO expected_cycle FROM public.courses WHERE id=NEW.course_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'El curso % del historial no existe.', NEW.course_id; END IF;
  IF expected_cycle IS NULL THEN RAISE EXCEPTION 'El curso del historial no tiene ciclo.'; END IF;
  IF NEW.cycle_id IS NOT NULL AND NEW.cycle_id IS DISTINCT FROM expected_cycle THEN
    RAISE EXCEPTION 'El historial no puede usar otro ciclo que el curso.';
  END IF;
  NEW.cycle_id := expected_cycle;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS mn_assign_calculation_cycle ON public.calculation_history;
DROP TRIGGER IF EXISTS mnf_set_calculation_history_cycle ON public.calculation_history;
CREATE TRIGGER mn_assign_calculation_cycle BEFORE INSERT OR UPDATE ON public.calculation_history
FOR EACH ROW EXECUTE FUNCTION public.mn_assign_calculation_cycle();

-- Proteccion de perfiles: elimina la posibilidad de elevar role/status mediante
-- INSERT o UPDATE, incluso si el cliente envia campos administrativos.
CREATE OR REPLACE FUNCTION public.mn_protect_profile_identity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF COALESCE(auth.role(),'') IN ('service_role','supabase_admin') OR auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF public.is_admin() THEN RETURN NEW; END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.id IS DISTINCT FROM auth.uid()
       OR lower(COALESCE(NEW.email,'')) <> lower(COALESCE(auth.jwt()->>'email','')) THEN
      RAISE EXCEPTION 'Un alumno solo puede crear su propio perfil con el correo de su sesion.';
    END IF;
    NEW.role := 'student'; NEW.status := 'active';
  ELSIF NEW.id IS DISTINCT FROM OLD.id
     OR lower(COALESCE(NEW.email,'')) <> lower(COALESCE(OLD.email,''))
     OR NEW.role IS DISTINCT FROM OLD.role OR NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION 'Un alumno no puede modificar identidad, correo, role ni status.';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS mn_protect_profile_identity ON public.profiles;
CREATE TRIGGER mn_protect_profile_identity BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.mn_protect_profile_identity();

-- Una fila de student_courses queda ligada a su curso y ciclo. El alumno puede
-- editar sus créditos/visibilidad, pero no transportar créditos entre ciclos.
-- ================================================================
-- 3. Protección de contexto académico.
-- ================================================================

UPDATE public.calculation_history h
SET cycle_id = c.cycle_id
FROM public.courses c
WHERE h.course_id = c.id
  AND h.cycle_id IS NULL
  AND c.cycle_id IS NOT NULL;

UPDATE public.student_courses sc
SET university_id = c.university_id,
    faculty_id = c.faculty_id,
    career_id = c.career_id,
    cycle_id = c.cycle_id
FROM public.courses c
WHERE sc.course_id = c.id
  AND (sc.university_id IS NULL OR sc.faculty_id IS NULL OR sc.career_id IS NULL OR sc.cycle_id IS NULL);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.student_courses sc
    JOIN public.courses c ON c.id = sc.course_id
    WHERE sc.university_id IS DISTINCT FROM c.university_id
       OR sc.faculty_id IS DISTINCT FROM c.faculty_id
       OR sc.career_id IS DISTINCT FROM c.career_id
       OR sc.cycle_id IS DISTINCT FROM c.cycle_id
  ) THEN
    RAISE EXCEPTION 'student_courses contiene contexto distinto al curso; no se instalaron triggers.';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.mnf_validate_student_course_context()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  expected record;
  privileged boolean;
BEGIN
  privileged := COALESCE(auth.role(),'') IN ('service_role','supabase_admin')
    OR auth.uid() IS NULL
    OR public.is_admin();
  IF NOT privileged THEN
    IF TG_OP = 'INSERT' AND NEW.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Un alumno solo puede agregar cursos a su propia lista.';
    END IF;
    IF TG_OP = 'UPDATE' AND (NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.course_id IS DISTINCT FROM OLD.course_id) THEN
      RAISE EXCEPTION 'Un alumno no puede mover una fila a otro usuario o curso.';
    END IF;
  END IF;
  SELECT c.university_id, c.faculty_id, c.career_id, c.cycle_id
  INTO expected
  FROM public.courses c
  WHERE c.id = NEW.course_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'El curso % no existe.', NEW.course_id; END IF;
  IF NEW.university_id IS NULL THEN NEW.university_id := expected.university_id; ELSIF NEW.university_id IS DISTINCT FROM expected.university_id THEN RAISE EXCEPTION 'La universidad del curso no coincide.'; END IF;
  IF NEW.faculty_id IS NULL THEN NEW.faculty_id := expected.faculty_id; ELSIF NEW.faculty_id IS DISTINCT FROM expected.faculty_id THEN RAISE EXCEPTION 'La facultad del curso no coincide.'; END IF;
  IF NEW.career_id IS NULL THEN NEW.career_id := expected.career_id; ELSIF NEW.career_id IS DISTINCT FROM expected.career_id THEN RAISE EXCEPTION 'La carrera del curso no coincide.'; END IF;
  IF NEW.cycle_id IS NULL THEN NEW.cycle_id := expected.cycle_id; ELSIF NEW.cycle_id IS DISTINCT FROM expected.cycle_id THEN RAISE EXCEPTION 'El ciclo del curso no coincide.'; END IF;
  IF TG_OP = 'UPDATE' AND NEW.credits IS DISTINCT FROM OLD.credits
     AND NEW.credits_confirmed_at IS NOT DISTINCT FROM OLD.credits_confirmed_at THEN
    NEW.credits_confirmed_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS mn_protect_student_course_context ON public.student_courses;
DROP TRIGGER IF EXISTS mnf_validate_student_course_context ON public.student_courses;
CREATE TRIGGER mnf_validate_student_course_context
BEFORE INSERT OR UPDATE
ON public.student_courses
FOR EACH ROW EXECUTE FUNCTION public.mnf_validate_student_course_context();

DROP FUNCTION IF EXISTS public.mn_protect_student_course_context();

-- ================================================================
-- 4. RLS: eliminar políticas históricas permisivas y recrear reglas
--    explícitas. RLS combina políticas permisivas con OR, por lo que
--    se eliminan también las políticas FOR ALL (cmd=ALL).
-- ================================================================

DO $$
DECLARE item record;
BEGIN
  FOR item IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('admin_emails', 'profiles', 'student_courses', 'student_weighted_preferences', 'course_grades', 'student_evaluation_scores', 'calculation_history')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', item.policyname, item.schemaname, item.tablename);
  END LOOP;
END $$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_weighted_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_evaluation_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calculation_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mnf_profiles_select_own_or_admin" ON public.profiles
FOR SELECT TO authenticated USING (id = auth.uid() OR public.is_admin());

CREATE POLICY "mnf_profiles_insert_admin" ON public.profiles
FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "mnf_profiles_insert_student_safe" ON public.profiles
FOR INSERT TO authenticated WITH CHECK (
  id = auth.uid()
  AND lower(email) = lower(COALESCE(auth.jwt()->>'email',''))
  AND role = 'student'
  AND status = 'active'
);

CREATE POLICY "mnf_profiles_update_student_safe" ON public.profiles
FOR UPDATE TO authenticated
USING (id = auth.uid() AND COALESCE(role, 'student') = 'student' AND COALESCE(status, 'active') = 'active')
WITH CHECK (id = auth.uid() AND role = 'student' AND status = 'active');

CREATE POLICY "mnf_profiles_update_admin" ON public.profiles
FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "mnf_admin_emails_select" ON public.admin_emails
FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "mnf_admin_emails_manage" ON public.admin_emails
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "mnf_student_courses_select_own_or_admin" ON public.student_courses
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "mnf_student_courses_insert_own" ON public.student_courses
FOR INSERT TO authenticated
WITH CHECK (
  public.is_active_user()
  AND user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.courses c
    JOIN public.profiles p ON p.id = auth.uid()
    WHERE c.id = student_courses.course_id
      AND c.status = 'active'
      AND student_courses.university_id IS NOT DISTINCT FROM c.university_id
      AND student_courses.faculty_id IS NOT DISTINCT FROM c.faculty_id
      AND student_courses.career_id IS NOT DISTINCT FROM c.career_id
      AND student_courses.cycle_id IS NOT DISTINCT FROM c.cycle_id
      AND c.university_id IS NOT DISTINCT FROM p.university_id
      AND c.faculty_id IS NOT DISTINCT FROM p.faculty_id
      AND c.career_id IS NOT DISTINCT FROM p.career_id
  )
);

CREATE POLICY "mnf_student_courses_update_own" ON public.student_courses
FOR UPDATE TO authenticated
USING (user_id = auth.uid() AND public.is_active_user())
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.courses c
    WHERE c.id = student_courses.course_id
      AND student_courses.university_id IS NOT DISTINCT FROM c.university_id
      AND student_courses.faculty_id IS NOT DISTINCT FROM c.faculty_id
      AND student_courses.career_id IS NOT DISTINCT FROM c.career_id
      AND student_courses.cycle_id IS NOT DISTINCT FROM c.cycle_id
  )
);

CREATE POLICY "mnf_student_courses_admin" ON public.student_courses
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "mnf_weighted_preferences_select_own_or_admin" ON public.student_weighted_preferences
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "mnf_weighted_preferences_insert_own" ON public.student_weighted_preferences
FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND public.is_active_user());

CREATE POLICY "mnf_weighted_preferences_update_own" ON public.student_weighted_preferences
FOR UPDATE TO authenticated
USING (user_id = auth.uid() AND public.is_active_user())
WITH CHECK (user_id = auth.uid() AND public.is_active_user());

CREATE POLICY "mnf_weighted_preferences_delete_own_or_admin" ON public.student_weighted_preferences
FOR DELETE TO authenticated USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "mnf_course_grades_select_own_or_admin" ON public.course_grades
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "mnf_course_grades_insert_own" ON public.course_grades
FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND public.is_active_user());
CREATE POLICY "mnf_course_grades_update_own" ON public.course_grades
FOR UPDATE TO authenticated USING (user_id = auth.uid() AND public.is_active_user()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "mnf_course_grades_delete_own_or_admin" ON public.course_grades
FOR DELETE TO authenticated USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "mnf_course_grades_admin" ON public.course_grades
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "mnf_student_scores_select_own_or_admin" ON public.student_evaluation_scores
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "mnf_student_scores_insert_own" ON public.student_evaluation_scores
FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND public.is_active_user());
CREATE POLICY "mnf_student_scores_update_own" ON public.student_evaluation_scores
FOR UPDATE TO authenticated USING (user_id = auth.uid() AND public.is_active_user()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "mnf_student_scores_delete_own_or_admin" ON public.student_evaluation_scores
FOR DELETE TO authenticated USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "mnf_student_scores_admin" ON public.student_evaluation_scores
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "mnf_history_select_own_or_admin" ON public.calculation_history
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "mnf_history_insert_own" ON public.calculation_history
FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND public.is_active_user());
CREATE POLICY "mnf_history_delete_own_or_admin" ON public.calculation_history
FOR DELETE TO authenticated USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "mnf_history_admin" ON public.calculation_history
FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

REVOKE ALL ON TABLE public.student_weighted_preferences FROM anon, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.student_weighted_preferences TO authenticated;
REVOKE ALL ON TABLE public.admin_emails, public.profiles, public.student_courses, public.course_grades,
  public.calculation_history, public.student_evaluation_scores FROM anon, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.admin_emails TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.student_courses, public.course_grades,
  public.calculation_history, public.student_evaluation_scores TO authenticated;

COMMIT;

-- ================================================================
-- 5. Validación posterior (solo lectura; no sustituye pruebas JWT).
-- ================================================================

SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name IN ('student_courses', 'student_weighted_preferences', 'calculation_history')
ORDER BY table_name, ordinal_position;

SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid::regclass::text IN ('public.student_courses', 'public.student_weighted_preferences', 'public.calculation_history')
ORDER BY table_name, conname;

SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname='public'
  AND tablename IN ('admin_emails', 'profiles', 'student_courses', 'student_weighted_preferences', 'course_grades', 'student_evaluation_scores', 'calculation_history')
ORDER BY tablename, policyname;

SELECT
  (SELECT count(*) FROM public.student_weighted_preferences WHERE enabled AND confirmed_at IS NULL) AS active_preferences_without_confirmation,
  (SELECT count(*) FROM public.student_courses sc JOIN public.courses c ON c.id=sc.course_id WHERE sc.cycle_id IS DISTINCT FROM c.cycle_id) AS student_course_cycle_mismatches,
  (SELECT count(*) FROM public.calculation_history h JOIN public.courses c ON c.id=h.course_id WHERE h.cycle_id IS DISTINCT FROM c.cycle_id) AS history_cycle_mismatches;
