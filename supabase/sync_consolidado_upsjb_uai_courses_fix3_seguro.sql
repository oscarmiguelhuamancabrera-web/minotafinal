-- ============================================================
-- MI NOTA FINAL - SCRIPT CONSOLIDADO DE CURSOS
-- Universidades incluidas:
--   1) UPSJB - sincronización según mallas PDF cargadas
--   2) UAI   - sincronización según brochures/mallas PDF cargadas
--
-- Acción:
--   - Inserta cursos oficiales faltantes.
--   - Reactiva cursos oficiales existentes.
--   - Da de baja lógica (status = 'inactive') a cursos que no coinciden
--     con las mallas oficiales dentro de las carreras sincronizadas.
--
-- IMPORTANTE:
--   - Ejecutar completo en Supabase SQL Editor.
--   - No elimina físicamente cursos por defecto.
--   - Respeta historial y notas porque usa baja lógica.
--   - Si alguna universidad tiene otro code en tu BD, cambiar UPSJB/UAI
--     dentro del bloque correspondiente antes de ejecutar.
-- ============================================================



-- ============================================================
-- BLOQUE 1: UPSJB
-- ============================================================

-- ============================================================
-- MI NOTA FINAL - SINCRONIZACIÓN DE CURSOS UPSJB SEGÚN MALLAS PDF
-- Acción principal: inserta cursos faltantes, reactiva los cursos oficiales
-- y da de baja lógica a cursos que NO coinciden con estas mallas.
--
-- IMPORTANTE:
-- 1) Ejecuta primero el bloque de PREVISUALIZACIÓN.
-- 2) Revisa carreras/ciclos no encontrados.
-- 3) Luego ejecuta el bloque APLICAR.
-- 4) Por seguridad, se recomienda BAJA LÓGICA (status='inactive'), no borrado físico.
-- ============================================================

-- ============================================================
-- BLOQUE COMÚN: datos oficiales extraídos de las mallas
-- ============================================================
create or replace function public.mn_normalize(txt text)
returns text
language sql
immutable
as $$
  select trim(
    regexp_replace(
      translate(lower(coalesce(txt, '')), 'áéíóúüñ', 'aeiouun'),
      '[^a-z0-9]+',
      ' ',
      'g'
    )
  );
$$;

drop table if exists tmp_malla_cursos_upsjb;
create temp table tmp_malla_cursos_upsjb (
  career_name text not null,
  cycle_order integer not null,
  course_name text not null
);

insert into tmp_malla_cursos_upsjb (career_name, cycle_order, course_name)
values
  ('Administración de Empresas', 1, 'Informática para Negocios'),
  ('Administración de Empresas', 1, 'Introducción a la Economía'),
  ('Administración de Empresas', 1, 'Psicología'),
  ('Administración de Empresas', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Administración de Empresas', 1, 'Lógico-Matemática'),
  ('Administración de Empresas', 1, 'Redacción e Interpretación de Textos'),
  ('Administración de Empresas', 2, 'Fundamentos de la Administración'),
  ('Administración de Empresas', 2, 'Matemática'),
  ('Administración de Empresas', 2, 'Inglés I'),
  ('Administración de Empresas', 2, 'Filosofía'),
  ('Administración de Empresas', 2, 'Realidad Nacional'),
  ('Administración de Empresas', 2, 'Comunicación y Medios Digitales'),
  ('Administración de Empresas', 3, 'Modelo de negocio y Creación de valor'),
  ('Administración de Empresas', 3, 'Métodos Estadísticos'),
  ('Administración de Empresas', 3, 'Interculturalidad'),
  ('Administración de Empresas', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Administración de Empresas', 3, 'Derecho Empresarial'),
  ('Administración de Empresas', 3, 'Inglés II'),
  ('Administración de Empresas', 4, 'Conocimiento, Tecnología y Globalización'),
  ('Administración de Empresas', 4, 'Sistemas Administrativos'),
  ('Administración de Empresas', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Administración de Empresas', 4, 'Matemática Financiera'),
  ('Administración de Empresas', 4, 'Derecho Laboral y Tributario'),
  ('Administración de Empresas', 4, 'Inglés Técnico'),
  ('Administración de Empresas', 5, 'Logística Internacional'),
  ('Administración de Empresas', 5, 'Teoría de la Innovación y Emprendimiento'),
  ('Administración de Empresas', 5, 'Metodología de la Investigación Científica'),
  ('Administración de Empresas', 5, 'Fundamentos y Doctrina Contable'),
  ('Administración de Empresas', 5, 'Auditoría Administrativa'),
  ('Administración de Empresas', 5, 'Electivo I'),
  ('Administración de Empresas', 6, 'Gestión de la Cadena de Abastecimiento'),
  ('Administración de Empresas', 6, 'Emprendimiento y Diseño de Productos y Servicios'),
  ('Administración de Empresas', 6, 'Introducción al Marketing'),
  ('Administración de Empresas', 6, 'Contabilidad Financiera I'),
  ('Administración de Empresas', 6, 'Comportamiento Humano en las Organizaciones'),
  ('Administración de Empresas', 6, 'Electivo II'),
  ('Administración de Empresas', 7, 'Operación de Comercio Internacional'),
  ('Administración de Empresas', 7, 'Creatividad para la Solución de problemas complejos'),
  ('Administración de Empresas', 7, 'Comportamiento del Consumidor'),
  ('Administración de Empresas', 7, 'Contabilidad Financiera II'),
  ('Administración de Empresas', 7, 'Administración del Talento Humano'),
  ('Administración de Empresas', 7, 'Electivo III'),
  ('Administración de Empresas', 8, 'Dirección y Planificación Estratégica'),
  ('Administración de Empresas', 8, 'Gestión de la Innovación Sostenible'),
  ('Administración de Empresas', 8, 'Investigación de Mercados'),
  ('Administración de Empresas', 8, 'Costos y Presupuestos Empresariales'),
  ('Administración de Empresas', 8, 'Ética y Profesionalismo'),
  ('Administración de Empresas', 8, 'Electivo IV'),
  ('Administración de Empresas', 9, 'Análisis de Datos y Sistemas de Información Gerencial'),
  ('Administración de Empresas', 9, 'Formulación y Evaluación de Proyectos'),
  ('Administración de Empresas', 9, 'Marketing Estratégico'),
  ('Administración de Empresas', 9, 'Finanzas Corporativas'),
  ('Administración de Empresas', 9, 'Estadística Inferencial'),
  ('Administración de Empresas', 9, 'Trabajo de Investigación I'),
  ('Administración de Empresas', 10, 'Prácticas Preprofesionales'),
  ('Administración de Empresas', 10, 'Gerencia de Marketing y Tecnología'),
  ('Administración de Empresas', 10, 'Dirección Financiera'),
  ('Administración de Empresas', 10, 'Responsabilidad Social Empresarial'),
  ('Administración de Empresas', 10, 'Trabajo de Investigación II'),
  ('Derecho', 1, 'Introducción al Derecho'),
  ('Derecho', 1, 'Vida Universitaria y Gestión de Conocimiento'),
  ('Derecho', 1, 'Derecho Constitucional I'),
  ('Derecho', 1, 'Lógico-Matemática'),
  ('Derecho', 1, 'Redacción e Interpretación de Textos'),
  ('Derecho', 1, 'Ciencia Política'),
  ('Derecho', 1, 'Derecho Romano'),
  ('Derecho', 2, 'Derecho de las personas'),
  ('Derecho', 2, 'Psicología Forense'),
  ('Derecho', 2, 'Derecho Constitucional II'),
  ('Derecho', 2, 'Realidad Nacional'),
  ('Derecho', 2, 'Filosofía'),
  ('Derecho', 2, 'Inglés I'),
  ('Derecho', 2, 'Comunicación y Medios Digitales'),
  ('Derecho', 3, 'Teoría General del proceso'),
  ('Derecho', 3, 'Medios alternativos de Resolución de conflictos'),
  ('Derecho', 3, 'Razonamiento Jurídico'),
  ('Derecho', 3, 'Lógica Jurídica'),
  ('Derecho', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Derecho', 3, 'Inglés II'),
  ('Derecho', 3, 'Interculturalidad'),
  ('Derecho', 4, 'Derecho Procesal Constitucional'),
  ('Derecho', 4, 'Derecho Administrativo'),
  ('Derecho', 4, 'Derecho del medio ambiente y Minería'),
  ('Derecho', 4, 'Acto Jurídico'),
  ('Derecho', 4, 'Derecho Penal general'),
  ('Derecho', 4, 'Oratoria Forense'),
  ('Derecho', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Derecho', 5, 'Derecho Procesal Civil I'),
  ('Derecho', 5, 'Derecho Procesal Administrativo, Proceso Contencioso Administrativo'),
  ('Derecho', 5, 'Constitución y Tratados Internacionales'),
  ('Derecho', 5, 'Derechos Reales'),
  ('Derecho', 5, 'Derecho Penal Especial'),
  ('Derecho', 5, 'Derecho Individual del Trabajo Público y Privado'),
  ('Derecho', 6, 'Derecho Procesal Civil II'),
  ('Derecho', 6, 'Regulación de Servicios Públicos'),
  ('Derecho', 6, 'Derecho procesal laboral y Técnicas de Litigación Oral'),
  ('Derecho', 6, 'Contratos'),
  ('Derecho', 6, 'Derecho de Familia, Niño y Adolescente'),
  ('Derecho', 6, 'Inglés Técnico'),
  ('Derecho', 7, 'Derecho Procesal Penal y Técnicas de Litigación Oral I'),
  ('Derecho', 7, 'Derecho Tributario y Procedimientos Tributarios'),
  ('Derecho', 7, 'Derecho Internacional Privado'),
  ('Derecho', 7, 'Derecho de las Obligaciones'),
  ('Derecho', 7, 'Derecho de Sucesiones'),
  ('Derecho', 7, 'Contratos Modernos y Bancarios'),
  ('Derecho', 7, 'Electivo'),
  ('Derecho', 8, 'Derecho procesal Penal y Técnicas de Litigación Oral II'),
  ('Derecho', 8, 'Contratación Estatal'),
  ('Derecho', 8, 'Jurisdicción Supranacional de los Derechos Humanos'),
  ('Derecho', 8, 'Derecho Societario, Fusiones y Adquisiciones'),
  ('Derecho', 8, 'Ética y Profesionalismo'),
  ('Derecho', 8, 'Electivo'),
  ('Derecho', 9, 'Técnicas de Litigación Oral en el Proceso Civil'),
  ('Derecho', 9, 'Derecho Internacional Público'),
  ('Derecho', 9, 'Derecho del Sistema Electoral'),
  ('Derecho', 9, 'Responsabilidad Civil'),
  ('Derecho', 9, 'Metodología de la Investigación Científica'),
  ('Derecho', 9, 'Electivo'),
  ('Derecho', 10, 'Derecho Penal Económico'),
  ('Derecho', 10, 'Regulación del Sistema Financiero'),
  ('Derecho', 10, 'Política Exterior y Diplomacia'),
  ('Derecho', 10, 'Derecho Notarial y Registral'),
  ('Derecho', 10, 'Métodos Estadísticos'),
  ('Derecho', 10, 'Electivo'),
  ('Derecho', 11, 'Derecho Procesal Militar y Policial'),
  ('Derecho', 11, 'Derecho de la Competencia'),
  ('Derecho', 11, 'Argumentación Jurídica y Teoría del Caso'),
  ('Derecho', 11, 'Comercio Exterior y Derecho Aduanero'),
  ('Derecho', 11, 'Trabajo de Investigación I'),
  ('Derecho', 12, 'Seminario de Integración de Derecho Procesal'),
  ('Derecho', 12, 'Seminario de Integración de Derecho Administrativo'),
  ('Derecho', 12, 'Seminario de Integración de Derecho Constitucional'),
  ('Derecho', 12, 'Seminario de Integración de Derecho Empresarial'),
  ('Derecho', 12, 'Trabajo de Investigación II'),
  ('Contabilidad', 1, 'Informática para Negocios'),
  ('Contabilidad', 1, 'Introducción a la Economía'),
  ('Contabilidad', 1, 'Psicología'),
  ('Contabilidad', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Contabilidad', 1, 'Lógico-Matemática'),
  ('Contabilidad', 1, 'Redacción e Interpretación de Textos'),
  ('Contabilidad', 2, 'Fundamentos y Doctrina Contable'),
  ('Contabilidad', 2, 'Matemática'),
  ('Contabilidad', 2, 'Inglés I'),
  ('Contabilidad', 2, 'Filosofía'),
  ('Contabilidad', 2, 'Realidad Nacional'),
  ('Contabilidad', 2, 'Comunicación y Medios Digitales'),
  ('Contabilidad', 3, 'Contabilidad Financiera I'),
  ('Contabilidad', 3, 'Métodos Estadísticos'),
  ('Contabilidad', 3, 'Contabilidad de Sociedades'),
  ('Contabilidad', 3, 'Interculturalidad'),
  ('Contabilidad', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Contabilidad', 3, 'Inglés II'),
  ('Contabilidad', 4, 'Contabilidad Financiera II'),
  ('Contabilidad', 4, 'Matemática Financiera'),
  ('Contabilidad', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Contabilidad', 4, 'Derecho Empresarial'),
  ('Contabilidad', 4, 'Conocimiento, Tecnología y Globalización'),
  ('Contabilidad', 4, 'Inglés Técnico'),
  ('Contabilidad', 5, 'Formulación de Estados Financieros'),
  ('Contabilidad', 5, 'Informática para la Gestión Contable y Empresarial'),
  ('Contabilidad', 5, 'Creatividad para la Solución de Problemas Complejos'),
  ('Contabilidad', 5, 'Derecho Laboral y Tributario'),
  ('Contabilidad', 5, 'Metodología de la Investigación Científica'),
  ('Contabilidad', 5, 'Electivo I'),
  ('Contabilidad', 6, 'Análisis e Interpretación de Estados Financieros'),
  ('Contabilidad', 6, 'Costos y Presupuestos Empresariales'),
  ('Contabilidad', 6, 'Comportamiento Humano en las Organizaciones'),
  ('Contabilidad', 6, 'Tributación Aplicada I'),
  ('Contabilidad', 6, 'Control Interno y Riesgos Financieros'),
  ('Contabilidad', 6, 'Electivo II'),
  ('Contabilidad', 7, 'Finanzas Corporativas'),
  ('Contabilidad', 7, 'Operación de Comercio Internacional'),
  ('Contabilidad', 7, 'Administración del Talento Humano'),
  ('Contabilidad', 7, 'Tributación Aplicada II'),
  ('Contabilidad', 7, 'Auditoría de la Información Financiera I'),
  ('Contabilidad', 7, 'Electivo III'),
  ('Contabilidad', 8, 'Dirección y Planificación Estratégica'),
  ('Contabilidad', 8, 'Normas Internacionales de Información Financiera'),
  ('Contabilidad', 8, 'Ética y Profesionalismo'),
  ('Contabilidad', 8, 'Auditoría Tributaria'),
  ('Contabilidad', 8, 'Auditoría de la Información Financiera II'),
  ('Contabilidad', 8, 'Electivo IV'),
  ('Contabilidad', 9, 'Planeamiento Financiero'),
  ('Contabilidad', 9, 'Contabilidad Aplicada'),
  ('Contabilidad', 9, 'Responsabilidad Social Empresarial'),
  ('Contabilidad', 9, 'Trabajo de Investigación I'),
  ('Contabilidad', 9, 'Auditoría Administrativa'),
  ('Contabilidad', 9, 'Estadística Inferencial'),
  ('Contabilidad', 10, 'Evaluación Financiera de las Empresas'),
  ('Contabilidad', 10, 'Análisis de Datos y Sistemas de Información Gerencial'),
  ('Contabilidad', 10, 'Prácticas Preprofesionales'),
  ('Contabilidad', 10, 'Trabajo de Investigación II'),
  ('Contabilidad', 10, 'Auditoría Integral'),
  ('Administración y Marketing', 1, 'Introducción a la Economía'),
  ('Administración y Marketing', 1, 'Informática para Negocios y Marketing'),
  ('Administración y Marketing', 1, 'Psicología'),
  ('Administración y Marketing', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Administración y Marketing', 1, 'Lógico - Matemática'),
  ('Administración y Marketing', 1, 'Redacción e Interpretación de Textos'),
  ('Administración y Marketing', 2, 'Fundamentos de la Administración'),
  ('Administración y Marketing', 2, 'Matemática'),
  ('Administración y Marketing', 2, 'Filosofía'),
  ('Administración y Marketing', 2, 'Comunicación y Medios Digitales'),
  ('Administración y Marketing', 2, 'Realidad Nacional'),
  ('Administración y Marketing', 2, 'Inglés I'),
  ('Administración y Marketing', 3, 'Introducción al Marketing'),
  ('Administración y Marketing', 3, 'Matemática Financiera'),
  ('Administración y Marketing', 3, 'Métodos Estadísticos'),
  ('Administración y Marketing', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Administración y Marketing', 3, 'Interculturalidad'),
  ('Administración y Marketing', 3, 'Inglés II'),
  ('Administración y Marketing', 4, 'Fundamentos de Marketing'),
  ('Administración y Marketing', 4, 'Finanzas'),
  ('Administración y Marketing', 4, 'Gestión Estadística de la Información'),
  ('Administración y Marketing', 4, 'Derecho Empresarial'),
  ('Administración y Marketing', 4, 'Inglés Técnico'),
  ('Administración y Marketing', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Administración y Marketing', 5, 'Investigación de Mercados'),
  ('Administración y Marketing', 5, 'Comportamiento del Consumidor'),
  ('Administración y Marketing', 5, 'Marketing Estratégico'),
  ('Administración y Marketing', 5, 'Contabilidad Gerencial'),
  ('Administración y Marketing', 5, 'Metodología de la Investigación Científica'),
  ('Administración y Marketing', 5, 'Electivo I'),
  ('Administración y Marketing', 6, 'Branding y Estrategia de Producto'),
  ('Administración y Marketing', 6, 'Trade Marketing y Retail'),
  ('Administración y Marketing', 6, 'Marketing Digital e Interactivo'),
  ('Administración y Marketing', 6, 'Gestión del Talento Humano'),
  ('Administración y Marketing', 6, 'Comportamiento Organizacional'),
  ('Administración y Marketing', 6, 'Electivo II'),
  ('Administración y Marketing', 7, 'Social Media Marketing'),
  ('Administración y Marketing', 7, 'Finanzas Aplicadas a Marketing'),
  ('Administración y Marketing', 7, 'Customer Relationship Management (CRM)'),
  ('Administración y Marketing', 7, 'Administración y Técnicas de Ventas'),
  ('Administración y Marketing', 7, 'Comunicación Integral de Marketing'),
  ('Administración y Marketing', 7, 'Electivo III'),
  ('Administración y Marketing', 8, 'Marketing Analytics y Consumer Insights'),
  ('Administración y Marketing', 8, 'Formulación y Evaluación de Proyectos'),
  ('Administración y Marketing', 8, 'Plan Estratégico de Marketing'),
  ('Administración y Marketing', 8, 'Marketing Internacional'),
  ('Administración y Marketing', 8, 'Ética y Profesionalismo'),
  ('Administración y Marketing', 8, 'Electivo IV'),
  ('Administración y Marketing', 9, 'Retail Management Avanzado'),
  ('Administración y Marketing', 9, 'Marketing de Servicios'),
  ('Administración y Marketing', 9, 'Dirección Estratégica'),
  ('Administración y Marketing', 9, 'Inteligencia Artificial Aplicada a Negocios'),
  ('Administración y Marketing', 9, 'Simulación de Negocios'),
  ('Administración y Marketing', 9, 'Trabajo de Investigación I'),
  ('Administración y Marketing', 10, 'Marketing Analytics Avanzado'),
  ('Administración y Marketing', 10, 'Prácticas Preprofesionales'),
  ('Administración y Marketing', 10, 'Trabajo de Investigación II'),
  ('Administración y Marketing', 10, 'Responsabilidad Social Empresarial'),
  ('Administración y Marketing', 10, 'Seminario de Tendencias en Marketing'),
  ('Enfermería', 1, 'Fundamentos Biológicos I'),
  ('Enfermería', 1, 'Bases de la Psicología Humana'),
  ('Enfermería', 1, 'Historia y Epistemología del Cuidado Enfermero'),
  ('Enfermería', 1, 'Vida Universitaria y Gestion del Conocimiento'),
  ('Enfermería', 1, 'Lógico - Matemática'),
  ('Enfermería', 1, 'Redacción e Interpretación de Textos'),
  ('Enfermería', 2, 'Fundamentos Biológicos II'),
  ('Enfermería', 2, 'Estructura y Función I'),
  ('Enfermería', 2, 'Comunicación y Medios Digitales'),
  ('Enfermería', 2, 'Realidad Nacional'),
  ('Enfermería', 2, 'Filosofía'),
  ('Enfermería', 2, 'Inglés I'),
  ('Enfermería', 3, 'Fundamentos Básicos del Cuidado Enfermero I'),
  ('Enfermería', 3, 'Bioquímica'),
  ('Enfermería', 3, 'Estructura y Función II'),
  ('Enfermería', 3, 'Interculturalidad'),
  ('Enfermería', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Enfermería', 3, 'Inglés II'),
  ('Enfermería', 3, 'Nutrición y Dietoterapia'),
  ('Enfermería', 4, 'Integrador - Fundamentos Básicos del Cuidado Enfermero II'),
  ('Enfermería', 4, 'Salud Familiar y Comunitaria'),
  ('Enfermería', 4, 'Epidemiología'),
  ('Enfermería', 4, 'Enfermería Legal y Legislación en Salud'),
  ('Enfermería', 4, 'Sistematización y Métodos Estadísticos'),
  ('Enfermería', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Enfermería', 4, 'Electivo 1'),
  ('Enfermería', 5, 'Cuidado Enfermero I'),
  ('Enfermería', 5, 'Simulación I (Reanimación Cardiopulmonar Básico)'),
  ('Enfermería', 5, 'Farmacología Aplicada a la Enfermería'),
  ('Enfermería', 5, 'Tecnologías de Empoderamiento Participativo en la Educación en Salud'),
  ('Enfermería', 5, 'Metodología de la Investigación'),
  ('Enfermería', 5, 'Electivo 2'),
  ('Enfermería', 6, 'Cuidado Enfermero II'),
  ('Enfermería', 6, 'Simulación II (Procedimientos Invasivos Básicos)'),
  ('Enfermería', 6, 'Recursos para la Alfabetización en Salud'),
  ('Enfermería', 6, 'Redacción y Publicación de Artículo I'),
  ('Enfermería', 6, 'Electivo 3'),
  ('Enfermería', 7, 'Cuidado Enfermero III'),
  ('Enfermería', 7, 'Simulación III (Procedimientos Invasivos Avanzados)'),
  ('Enfermería', 7, 'Gestión Estratégica y Emprendimiento'),
  ('Enfermería', 7, 'Redacción y Publicación de Artículo II'),
  ('Enfermería', 7, 'Electivo 4'),
  ('Enfermería', 8, 'Cuidado Enfermero IV'),
  ('Enfermería', 8, 'Emergencias y Urgencias en Enfermería'),
  ('Enfermería', 8, 'Seminario Integrador II'),
  ('Enfermería', 8, 'Gestión de los Servicios de Enfermería'),
  ('Enfermería', 8, 'Ética y Profesionalismo'),
  ('Enfermería', 9, 'Primera Rotación de Internado Comunitario I'),
  ('Enfermería', 9, 'Segunda Rotación de Internado Comunitario II'),
  ('Enfermería', 9, 'Taller Guía de Proyecto de Tesis'),
  ('Enfermería', 10, 'Tercera Rotación de Internado Clínico I'),
  ('Enfermería', 10, 'Cuarta Rotación de Internado Clínico II'),
  ('Enfermería', 10, 'Trabajo de Investigación'),
  ('Ingeniería Agroindustrial', 1, 'Introducción a la Ing. Agroindustrial y Vitivinicultura'),
  ('Ingeniería Agroindustrial', 1, 'Biología General'),
  ('Ingeniería Agroindustrial', 1, 'Química General'),
  ('Ingeniería Agroindustrial', 1, 'Geometría Analítica y Álgebra Lineal'),
  ('Ingeniería Agroindustrial', 1, 'Lógico-Matemática'),
  ('Ingeniería Agroindustrial', 1, 'Redacción e Interpretación de Textos'),
  ('Ingeniería Agroindustrial', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Ingeniería Agroindustrial', 2, 'Química Inorgánica'),
  ('Ingeniería Agroindustrial', 2, 'Física I'),
  ('Ingeniería Agroindustrial', 2, 'Cálculo Diferencial'),
  ('Ingeniería Agroindustrial', 2, 'Comunicación y Medios Digitales'),
  ('Ingeniería Agroindustrial', 2, 'Realidad Nacional'),
  ('Ingeniería Agroindustrial', 2, 'Filosofía'),
  ('Ingeniería Agroindustrial', 2, 'Inglés I'),
  ('Ingeniería Agroindustrial', 3, 'Cultivos Agroindustriales y Viticultura'),
  ('Ingeniería Agroindustrial', 3, 'Química Orgánica'),
  ('Ingeniería Agroindustrial', 3, 'Física II'),
  ('Ingeniería Agroindustrial', 3, 'Cálculo Integral'),
  ('Ingeniería Agroindustrial', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Ingeniería Agroindustrial', 3, 'Interculturalidad'),
  ('Ingeniería Agroindustrial', 3, 'Inglés II'),
  ('Ingeniería Agroindustrial', 4, 'Microbiología General'),
  ('Ingeniería Agroindustrial', 4, 'Informática Aplicada a la Ingeniería'),
  ('Ingeniería Agroindustrial', 4, 'Fisicoquímica'),
  ('Ingeniería Agroindustrial', 4, 'Química Analítica'),
  ('Ingeniería Agroindustrial', 4, 'Estadística General'),
  ('Ingeniería Agroindustrial', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Ingeniería Agroindustrial', 5, 'Introducción al Análisis Sensorial'),
  ('Ingeniería Agroindustrial', 5, 'Tecnología de la Energía y Fenómenos de Transporte'),
  ('Ingeniería Agroindustrial', 5, 'Microbiología y Biotecnología Agroalimentaria'),
  ('Ingeniería Agroindustrial', 5, 'Química Analítica Instrumental'),
  ('Ingeniería Agroindustrial', 5, 'Dibujo Técnico y Sistemas de Representación'),
  ('Ingeniería Agroindustrial', 5, 'Bioquímica'),
  ('Ingeniería Agroindustrial', 5, 'Termodinámica y Cinética'),
  ('Ingeniería Agroindustrial', 6, 'Tecnología Agroindustrial de Frutas y Hortalizas'),
  ('Ingeniería Agroindustrial', 6, 'Marketing Empresarial'),
  ('Ingeniería Agroindustrial', 6, 'Ingeniería de las Reacciones Químicas y Bioprocesos'),
  ('Ingeniería Agroindustrial', 6, 'Zootecnia'),
  ('Ingeniería Agroindustrial', 6, 'Operaciones Unitarias I'),
  ('Ingeniería Agroindustrial', 6, 'Metodología de la Investigación Científica'),
  ('Ingeniería Agroindustrial', 7, 'Tecnología Agroindustrial de Lácteos y Derivados'),
  ('Ingeniería Agroindustrial', 7, 'Análisis Sensorial de Alimentos'),
  ('Ingeniería Agroindustrial', 7, 'Instrumentación, Circuitos, Máquinas Eléctricas y Automatización de Procesos'),
  ('Ingeniería Agroindustrial', 7, 'Prácticas Preprofesionales I'),
  ('Ingeniería Agroindustrial', 7, 'Bromatología y Nutrición'),
  ('Ingeniería Agroindustrial', 7, 'Operaciones Unitarias II'),
  ('Ingeniería Agroindustrial', 7, 'Electivo I'),
  ('Ingeniería Agroindustrial', 8, 'Tecnología Agroindustrial de Cárnicos'),
  ('Ingeniería Agroindustrial', 8, 'Agroexportación y Comercio Internacional'),
  ('Ingeniería Agroindustrial', 8, 'Costos y Finanzas'),
  ('Ingeniería Agroindustrial', 8, 'Control de Calidad de Productos Agroindustriales y Vitivinícolas'),
  ('Ingeniería Agroindustrial', 8, 'Diseño de Experimentos'),
  ('Ingeniería Agroindustrial', 8, 'Ética y Profesionalismo'),
  ('Ingeniería Agroindustrial', 8, 'Electivo II'),
  ('Ingeniería Agroindustrial', 9, 'Normativa y Legislación Agroindustrial y Vitivinícola'),
  ('Ingeniería Agroindustrial', 9, 'Diseño de Plantas, Materiales e Instalaciones Agroindustriales y Vitivinícolas'),
  ('Ingeniería Agroindustrial', 9, 'Toxicología de Alimentos'),
  ('Ingeniería Agroindustrial', 9, 'Formulación y Evaluación de Proyectos'),
  ('Ingeniería Agroindustrial', 9, 'Tecnología Agroindustrial de Granos y Cereales'),
  ('Ingeniería Agroindustrial', 9, 'Trabajo de Investigación I'),
  ('Ingeniería Agroindustrial', 9, 'Electivo III'),
  ('Ingeniería Agroindustrial', 10, 'Tecnología Agroindustrial de Bebidas y Licores'),
  ('Ingeniería Agroindustrial', 10, 'Empacado y Embalaje Agroindustrial'),
  ('Ingeniería Agroindustrial', 10, 'Sistemas de Gestión de Calidad y Seguridad Agroindustrial y Vitivinícola'),
  ('Ingeniería Agroindustrial', 10, 'Prácticas Preprofesionales II'),
  ('Ingeniería Agroindustrial', 10, 'Trabajo de Investigación II'),
  ('Ingeniería Agroindustrial', 10, 'Electivo IV'),
  ('Ingeniería en Enología y Viticultura', 1, 'Introducción a la Ing. Agroindustrial y Vitivinicultura'),
  ('Ingeniería en Enología y Viticultura', 1, 'Biología General'),
  ('Ingeniería en Enología y Viticultura', 1, 'Química General'),
  ('Ingeniería en Enología y Viticultura', 1, 'Geometría Analítica y Álgebra Lineal'),
  ('Ingeniería en Enología y Viticultura', 1, 'Lógico-Matemática'),
  ('Ingeniería en Enología y Viticultura', 1, 'Redacción e Interpretación de Textos'),
  ('Ingeniería en Enología y Viticultura', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Ingeniería en Enología y Viticultura', 2, 'Química Inorgánica'),
  ('Ingeniería en Enología y Viticultura', 2, 'Física I'),
  ('Ingeniería en Enología y Viticultura', 2, 'Cálculo Diferencial'),
  ('Ingeniería en Enología y Viticultura', 2, 'Comunicación y Medios Digitales'),
  ('Ingeniería en Enología y Viticultura', 2, 'Realidad Nacional'),
  ('Ingeniería en Enología y Viticultura', 2, 'Filosofía'),
  ('Ingeniería en Enología y Viticultura', 2, 'Inglés I'),
  ('Ingeniería en Enología y Viticultura', 3, 'Cultivos Agroindustriales y Viticultura'),
  ('Ingeniería en Enología y Viticultura', 3, 'Química Orgánica'),
  ('Ingeniería en Enología y Viticultura', 3, 'Física II'),
  ('Ingeniería en Enología y Viticultura', 3, 'Cálculo Integral'),
  ('Ingeniería en Enología y Viticultura', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Ingeniería en Enología y Viticultura', 3, 'Interculturalidad'),
  ('Ingeniería en Enología y Viticultura', 3, 'Inglés II'),
  ('Ingeniería en Enología y Viticultura', 4, 'Microbiología General'),
  ('Ingeniería en Enología y Viticultura', 4, 'Informática Aplicada a la Ingeniería'),
  ('Ingeniería en Enología y Viticultura', 4, 'Fisicoquímica'),
  ('Ingeniería en Enología y Viticultura', 4, 'Química Analítica'),
  ('Ingeniería en Enología y Viticultura', 4, 'Estadística General'),
  ('Ingeniería en Enología y Viticultura', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Ingeniería en Enología y Viticultura', 5, 'Introducción al Análisis Sensorial'),
  ('Ingeniería en Enología y Viticultura', 5, 'Tecnología de la Energía y Fenómenos de Transporte'),
  ('Ingeniería en Enología y Viticultura', 5, 'Microbiología y Biotecnología Agroalimentaria'),
  ('Ingeniería en Enología y Viticultura', 5, 'Química Analítica Instrumental'),
  ('Ingeniería en Enología y Viticultura', 5, 'Dibujo Técnico y Sistemas de Representación'),
  ('Ingeniería en Enología y Viticultura', 5, 'Bioquímica'),
  ('Ingeniería en Enología y Viticultura', 5, 'Termodinámica y Cinética'),
  ('Ingeniería en Enología y Viticultura', 6, 'Tecnología Agroindustrial de Frutas y Hortalizas'),
  ('Ingeniería en Enología y Viticultura', 6, 'Marketing Empresarial'),
  ('Ingeniería en Enología y Viticultura', 6, 'Ingeniería de las Reacciones Químicas y Bioprocesos'),
  ('Ingeniería en Enología y Viticultura', 6, 'Zootecnia'),
  ('Ingeniería en Enología y Viticultura', 6, 'Operaciones Unitarias I'),
  ('Ingeniería en Enología y Viticultura', 6, 'Metodología de la Investigación Científica'),
  ('Ingeniería en Enología y Viticultura', 7, 'Tecnología Agroindustrial de Lácteos y Derivados'),
  ('Ingeniería en Enología y Viticultura', 7, 'Análisis Sensorial de Alimentos'),
  ('Ingeniería en Enología y Viticultura', 7, 'Instrumentación, Circuitos, Máquinas Eléctricas y Automatización de Procesos'),
  ('Ingeniería en Enología y Viticultura', 7, 'Prácticas Preprofesionales I'),
  ('Ingeniería en Enología y Viticultura', 7, 'Bromatología y Nutrición'),
  ('Ingeniería en Enología y Viticultura', 7, 'Operaciones Unitarias II'),
  ('Ingeniería en Enología y Viticultura', 7, 'Electivo I'),
  ('Ingeniería en Enología y Viticultura', 8, 'Tecnología Agroindustrial de Cárnicos'),
  ('Ingeniería en Enología y Viticultura', 8, 'Agroexportación y Comercio Internacional'),
  ('Ingeniería en Enología y Viticultura', 8, 'Costos y Finanzas'),
  ('Ingeniería en Enología y Viticultura', 8, 'Control de Calidad de Productos Agroindustriales y Vitivinícolas'),
  ('Ingeniería en Enología y Viticultura', 8, 'Diseño de Experimentos'),
  ('Ingeniería en Enología y Viticultura', 8, 'Ética y Profesionalismo'),
  ('Ingeniería en Enología y Viticultura', 8, 'Electivo II'),
  ('Ingeniería en Enología y Viticultura', 9, 'Normativa y Legislación Agroindustrial y Vitivinícola'),
  ('Ingeniería en Enología y Viticultura', 9, 'Diseño de Plantas, Materiales e Instalaciones Agroindustriales y Vitivinícolas'),
  ('Ingeniería en Enología y Viticultura', 9, 'Toxicología de Alimentos'),
  ('Ingeniería en Enología y Viticultura', 9, 'Formulación y Evaluación de Proyectos'),
  ('Ingeniería en Enología y Viticultura', 9, 'Tecnología Agroindustrial de Granos y Cereales'),
  ('Ingeniería en Enología y Viticultura', 9, 'Trabajo de Investigación I'),
  ('Ingeniería en Enología y Viticultura', 9, 'Electivo III'),
  ('Ingeniería en Enología y Viticultura', 10, 'Tecnología Agroindustrial de Bebidas y Licores'),
  ('Ingeniería en Enología y Viticultura', 10, 'Empacado y Embalaje Agroindustrial'),
  ('Ingeniería en Enología y Viticultura', 10, 'Sistemas de Gestión de Calidad y Seguridad Agroindustrial y Vitivinícola'),
  ('Ingeniería en Enología y Viticultura', 10, 'Prácticas Preprofesionales II'),
  ('Ingeniería en Enología y Viticultura', 10, 'Trabajo de Investigación II'),
  ('Ingeniería en Enología y Viticultura', 10, 'Electivo IV'),
  ('Medicina Humana', 1, 'Bases Moleculares y Celulares de la Medicina I'),
  ('Medicina Humana', 1, 'Tecnologías de la Información, Comunicación, Conocimiento y Aprendizaje Digital (TICCAD)'),
  ('Medicina Humana', 1, 'Historia de la Medicina y Quechua Médico'),
  ('Medicina Humana', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Medicina Humana', 1, 'Lógico-Matemática'),
  ('Medicina Humana', 1, 'Redacción e Interpretación de Textos'),
  ('Medicina Humana', 2, 'Bases Moleculares y Celulares de la Medicina II'),
  ('Medicina Humana', 2, 'Estructura y Función de los Sistemas del Cuerpo Humano I'),
  ('Medicina Humana', 2, 'Comunicación y Medios Digitales'),
  ('Medicina Humana', 2, 'Realidad Nacional'),
  ('Medicina Humana', 2, 'Filosofía'),
  ('Medicina Humana', 2, 'Inglés I'),
  ('Medicina Humana', 3, 'Bases Moleculares y Celulares de la Medicina III'),
  ('Medicina Humana', 3, 'Estructura y Función de los Sistemas del Cuerpo Humano II'),
  ('Medicina Humana', 3, 'Bioética'),
  ('Medicina Humana', 3, 'Interculturalidad'),
  ('Medicina Humana', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Medicina Humana', 3, 'Inglés II'),
  ('Medicina Humana', 4, 'Microbiología y Parasitología Médica'),
  ('Medicina Humana', 4, 'Estructura y Función de los Sistemas del Cuerpo Humano III'),
  ('Medicina Humana', 4, 'Inmunología'),
  ('Medicina Humana', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Medicina Humana', 4, 'Medicina Conductual'),
  ('Medicina Humana', 5, 'Terapéutica y Cuidados Paliativos'),
  ('Medicina Humana', 5, 'Patología General'),
  ('Medicina Humana', 5, 'Integradora - Fisiopatología'),
  ('Medicina Humana', 5, 'Salud Comunitaria'),
  ('Medicina Humana', 5, 'Sistematización y Métodos Estadísticos'),
  ('Medicina Humana', 5, 'Electivo 1'),
  ('Medicina Humana', 6, 'Introducción a la Clínica'),
  ('Medicina Humana', 6, 'Simulación I (Procedimientos Invasivos Básicos)'),
  ('Medicina Humana', 6, 'Patología Clínica e Imagenología'),
  ('Medicina Humana', 6, 'Epidemiología'),
  ('Medicina Humana', 6, 'Metodología de la Investigación'),
  ('Medicina Humana', 7, 'Clínica y Terapéutica en Medicina I'),
  ('Medicina Humana', 7, 'Simulación II (Reanimación Cardiopulmonar Básico)'),
  ('Medicina Humana', 7, 'Genética Médica'),
  ('Medicina Humana', 7, 'Redacción y Publicación de Artículos I'),
  ('Medicina Humana', 7, 'Electivo 2'),
  ('Medicina Humana', 8, 'Clínica y Terapéutica en Medicina II'),
  ('Medicina Humana', 8, 'Simulación III (Procedimientos Invasivos Avanzados)'),
  ('Medicina Humana', 8, 'Medicina Intercultural'),
  ('Medicina Humana', 8, 'Ética y Profesionalismo'),
  ('Medicina Humana', 8, 'Electivo 3'),
  ('Medicina Humana', 9, 'Atención del Paciente en Salud Mental'),
  ('Medicina Humana', 9, 'Clínica y Terapéutica en Cirugía I'),
  ('Medicina Humana', 9, 'Seminario de Ciencias Básicas Aplicadas a la Clínica I'),
  ('Medicina Humana', 9, 'Gestión Estratégica y Emprendimiento en Servicios de Salud'),
  ('Medicina Humana', 9, 'Redacción y Publicación de Artículos II'),
  ('Medicina Humana', 10, 'Atención del Paciente Oncológico'),
  ('Medicina Humana', 10, 'Clínica y Terapéutica en Cirugía II'),
  ('Medicina Humana', 10, 'Seminario de Ciencias Básicas Aplicadas a la Clínica II'),
  ('Medicina Humana', 10, 'Medicina Legal'),
  ('Medicina Humana', 10, 'Taller Guía de Proyecto de Tesis'),
  ('Medicina Humana', 11, 'Externado en Primer Nivel de Atención I'),
  ('Medicina Humana', 11, 'Clínica y Terapéutica en Gineco-Obstetricia'),
  ('Medicina Humana', 11, 'Seminario Integrador I'),
  ('Medicina Humana', 11, 'Atención Integral e Integrada en Salud'),
  ('Medicina Humana', 11, 'Taller Guía de Tesis'),
  ('Medicina Humana', 12, 'Clínica y Terapéutica en Pediatría'),
  ('Medicina Humana', 12, 'Externado en Primer Nivel de Atención II'),
  ('Medicina Humana', 12, 'Seminario Integrador II'),
  ('Medicina Humana', 12, 'Electivo 4'),
  ('Medicina Humana', 13, 'Primera Rotación de Internado'),
  ('Medicina Humana', 13, 'Segunda Rotación de Internado'),
  ('Medicina Humana', 13, 'Seminario Integrador III'),
  ('Medicina Humana', 14, 'Tercera Rotación de Internado'),
  ('Medicina Humana', 14, 'Cuarta Rotación de Internado'),
  ('Medicina Humana', 14, 'Trabajo de Investigación'),
  ('Laboratorio Clínico y Anatomía Patológica', 1, 'Biología General'),
  ('Laboratorio Clínico y Anatomía Patológica', 1, 'Química Inorgánica'),
  ('Laboratorio Clínico y Anatomía Patológica', 1, 'Física Médica'),
  ('Laboratorio Clínico y Anatomía Patológica', 1, 'Taller de Ciencias Laboratoriales'),
  ('Laboratorio Clínico y Anatomía Patológica', 1, 'Lógico-Matemática'),
  ('Laboratorio Clínico y Anatomía Patológica', 1, 'Redacción e Interpretación de Textos'),
  ('Laboratorio Clínico y Anatomía Patológica', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Laboratorio Clínico y Anatomía Patológica', 2, 'Fisicoquímica'),
  ('Laboratorio Clínico y Anatomía Patológica', 2, 'Química Orgánica'),
  ('Laboratorio Clínico y Anatomía Patológica', 2, 'Anatomofisiología'),
  ('Laboratorio Clínico y Anatomía Patológica', 2, 'Realidad Nacional'),
  ('Laboratorio Clínico y Anatomía Patológica', 2, 'Filosofía'),
  ('Laboratorio Clínico y Anatomía Patológica', 2, 'Inglés I'),
  ('Laboratorio Clínico y Anatomía Patológica', 2, 'Comunicación y Medios Digitales'),
  ('Laboratorio Clínico y Anatomía Patológica', 3, 'Instrumentación y Equipos de Laboratorio Clínico'),
  ('Laboratorio Clínico y Anatomía Patológica', 3, 'Bioquímica General'),
  ('Laboratorio Clínico y Anatomía Patológica', 3, 'Histología'),
  ('Laboratorio Clínico y Anatomía Patológica', 3, 'Interculturalidad'),
  ('Laboratorio Clínico y Anatomía Patológica', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Laboratorio Clínico y Anatomía Patológica', 3, 'Inglés II'),
  ('Laboratorio Clínico y Anatomía Patológica', 3, 'Electivo 1'),
  ('Laboratorio Clínico y Anatomía Patológica', 4, 'Parasitología'),
  ('Laboratorio Clínico y Anatomía Patológica', 4, 'Bioquímica aplicada al Laboratorio Clínico'),
  ('Laboratorio Clínico y Anatomía Patológica', 4, 'Citotecnología'),
  ('Laboratorio Clínico y Anatomía Patológica', 4, 'Fisiopatología'),
  ('Laboratorio Clínico y Anatomía Patológica', 4, 'Sistematización y Métodos Estadísticos'),
  ('Laboratorio Clínico y Anatomía Patológica', 4, 'Inglés Técnico'),
  ('Laboratorio Clínico y Anatomía Patológica', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Laboratorio Clínico y Anatomía Patológica', 5, 'Bacteriología'),
  ('Laboratorio Clínico y Anatomía Patológica', 5, 'Inmunología General'),
  ('Laboratorio Clínico y Anatomía Patológica', 5, 'Toxicología'),
  ('Laboratorio Clínico y Anatomía Patológica', 5, 'Hematología General'),
  ('Laboratorio Clínico y Anatomía Patológica', 5, 'Metodología de la Investigación'),
  ('Laboratorio Clínico y Anatomía Patológica', 5, 'Salud Comunitaria'),
  ('Laboratorio Clínico y Anatomía Patológica', 6, 'Micología'),
  ('Laboratorio Clínico y Anatomía Patológica', 6, 'Inmunología aplicada al Laboratorio Clínico'),
  ('Laboratorio Clínico y Anatomía Patológica', 6, 'Histotecnología'),
  ('Laboratorio Clínico y Anatomía Patológica', 6, 'Hematología aplicada al Laboratorio Clínico'),
  ('Laboratorio Clínico y Anatomía Patológica', 6, 'Epidemiología'),
  ('Laboratorio Clínico y Anatomía Patológica', 6, 'Gestión de Calidad en Laboratorio Clínico'),
  ('Laboratorio Clínico y Anatomía Patológica', 6, 'Electivo 2'),
  ('Laboratorio Clínico y Anatomía Patológica', 7, 'Virología'),
  ('Laboratorio Clínico y Anatomía Patológica', 7, 'Biología Molecular'),
  ('Laboratorio Clínico y Anatomía Patológica', 7, 'Citogenética'),
  ('Laboratorio Clínico y Anatomía Patológica', 7, 'Interpretación de pruebas de Laboratorio Clínico'),
  ('Laboratorio Clínico y Anatomía Patológica', 7, 'Redacción y Publicación de artículos I'),
  ('Laboratorio Clínico y Anatomía Patológica', 7, 'Administración y Gestión en Servicios de Salud'),
  ('Laboratorio Clínico y Anatomía Patológica', 7, 'Electivo 3'),
  ('Laboratorio Clínico y Anatomía Patológica', 8, 'Microbiología Clínica'),
  ('Laboratorio Clínico y Anatomía Patológica', 8, 'Externado aplicado al Laboratorio Clínico'),
  ('Laboratorio Clínico y Anatomía Patológica', 8, 'Laboratorio Forense'),
  ('Laboratorio Clínico y Anatomía Patológica', 8, 'Banco de sangre y medicina transfusional'),
  ('Laboratorio Clínico y Anatomía Patológica', 8, 'Redacción y Publicación de artículos II'),
  ('Laboratorio Clínico y Anatomía Patológica', 8, 'Ética y Profesionalismo'),
  ('Laboratorio Clínico y Anatomía Patológica', 8, 'Electivo 4'),
  ('Laboratorio Clínico y Anatomía Patológica', 9, 'Primera Rotación'),
  ('Laboratorio Clínico y Anatomía Patológica', 9, 'Segunda Rotación'),
  ('Laboratorio Clínico y Anatomía Patológica', 9, 'Taller Guía de Proyecto de Tesis'),
  ('Laboratorio Clínico y Anatomía Patológica', 10, 'Tercera Rotación'),
  ('Laboratorio Clínico y Anatomía Patológica', 10, 'Cuarta Rotación'),
  ('Laboratorio Clínico y Anatomía Patológica', 10, 'Trabajo de Investigación'),
  ('Terapia Física y Rehabilitación', 1, 'Química y Bioquímica'),
  ('Terapia Física y Rehabilitación', 1, 'Biofísica Aplicada a la Fisioterapia'),
  ('Terapia Física y Rehabilitación', 1, 'Biología General'),
  ('Terapia Física y Rehabilitación', 1, 'Salud Mental y Discapacidad'),
  ('Terapia Física y Rehabilitación', 1, 'Lógico-Matemática'),
  ('Terapia Física y Rehabilitación', 1, 'Redacción e Interpretación de Textos'),
  ('Terapia Física y Rehabilitación', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Terapia Física y Rehabilitación', 2, 'Morfofisiología I'),
  ('Terapia Física y Rehabilitación', 2, 'Neuroanatomofisiología'),
  ('Terapia Física y Rehabilitación', 2, 'Comunicación y Medios Digitales'),
  ('Terapia Física y Rehabilitación', 2, 'Realidad Nacional'),
  ('Terapia Física y Rehabilitación', 2, 'Filosofía'),
  ('Terapia Física y Rehabilitación', 2, 'Inglés I'),
  ('Terapia Física y Rehabilitación', 2, 'Electivo 1'),
  ('Terapia Física y Rehabilitación', 3, 'Fisiología de la Actividad Física y Deportiva'),
  ('Terapia Física y Rehabilitación', 3, 'Morfofisiología II'),
  ('Terapia Física y Rehabilitación', 3, 'Fisiopatología Musculoesquelética'),
  ('Terapia Física y Rehabilitación', 3, 'Anatomía Funcional'),
  ('Terapia Física y Rehabilitación', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Terapia Física y Rehabilitación', 3, 'Inglés II'),
  ('Terapia Física y Rehabilitación', 3, 'Interculturalidad'),
  ('Terapia Física y Rehabilitación', 4, 'Evaluación y Diagnóstico Fisioterapéutico'),
  ('Terapia Física y Rehabilitación', 4, 'Desarrollo Psicomotor'),
  ('Terapia Física y Rehabilitación', 4, 'Neurociencias Aplicadas al dolor'),
  ('Terapia Física y Rehabilitación', 4, 'Biomecánica y Análisis del Movimiento'),
  ('Terapia Física y Rehabilitación', 4, 'Sistematización y Métodos Estadísticos'),
  ('Terapia Física y Rehabilitación', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Terapia Física y Rehabilitación', 4, 'Electivo 2'),
  ('Terapia Física y Rehabilitación', 5, 'Kinesioterapia'),
  ('Terapia Física y Rehabilitación', 5, 'Fisiopatología Neurológica'),
  ('Terapia Física y Rehabilitación', 5, 'Agentes Físicos y Electroterapéuticos'),
  ('Terapia Física y Rehabilitación', 5, 'Prevención y Ergonomía'),
  ('Terapia Física y Rehabilitación', 5, 'Metodología de la Investigación'),
  ('Terapia Física y Rehabilitación', 5, 'Inglés Técnico I'),
  ('Terapia Física y Rehabilitación', 5, 'Electivo 3'),
  ('Terapia Física y Rehabilitación', 6, 'Fisioterapia manual'),
  ('Terapia Física y Rehabilitación', 6, 'Psicomotricidad'),
  ('Terapia Física y Rehabilitación', 6, 'Razonamiento Clínico en Fisioterapia'),
  ('Terapia Física y Rehabilitación', 6, 'Salud Comunitaria'),
  ('Terapia Física y Rehabilitación', 6, 'Epidemiología'),
  ('Terapia Física y Rehabilitación', 6, 'Inglés Técnico II'),
  ('Terapia Física y Rehabilitación', 6, 'Electivo 4'),
  ('Terapia Física y Rehabilitación', 7, 'Evaluación y Fisioterapia Musculoesquelética'),
  ('Terapia Física y Rehabilitación', 7, 'Neurorrehabilitación Pediátrica'),
  ('Terapia Física y Rehabilitación', 7, 'Evaluación y Fisioterapia Cardiorrespiratoria'),
  ('Terapia Física y Rehabilitación', 7, 'Administración y Gestión en Servicios de Salud'),
  ('Terapia Física y Rehabilitación', 7, 'Redacción y Publicación de artículos I'),
  ('Terapia Física y Rehabilitación', 7, 'Ayudas Biomecánicas'),
  ('Terapia Física y Rehabilitación', 8, 'Externado en Fisioterapia'),
  ('Terapia Física y Rehabilitación', 8, 'Neurorrehabilitación en adultos'),
  ('Terapia Física y Rehabilitación', 8, 'Evaluación y Fisioterapia en Cirugía'),
  ('Terapia Física y Rehabilitación', 8, 'Fisioterapia en Atención Primaria'),
  ('Terapia Física y Rehabilitación', 8, 'Redacción y Publicación de artículos II'),
  ('Terapia Física y Rehabilitación', 8, 'Ética y Profesionalismo'),
  ('Terapia Física y Rehabilitación', 9, 'Primera Rotación'),
  ('Terapia Física y Rehabilitación', 9, 'Segunda Rotación'),
  ('Terapia Física y Rehabilitación', 9, 'Taller Guía de Proyecto de Tesis'),
  ('Terapia Física y Rehabilitación', 10, 'Tercera Rotación'),
  ('Terapia Física y Rehabilitación', 10, 'Cuarta Rotación'),
  ('Terapia Física y Rehabilitación', 10, 'Trabajo de Investigación'),
  ('Estomatología', 1, 'Microbiología Oral'),
  ('Estomatología', 1, 'Morfofisiología General y Aplicada'),
  ('Estomatología', 1, 'Materiales Dentales'),
  ('Estomatología', 1, 'Redacción e Interpretación de Textos'),
  ('Estomatología', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Estomatología', 1, 'Lógico-Matemática'),
  ('Estomatología', 2, 'Química y Bioquímica General y Aplicada'),
  ('Estomatología', 2, 'Histología y Embriología General y Aplicada'),
  ('Estomatología', 2, 'Comunicación y Medios Digitales'),
  ('Estomatología', 2, 'Inglés I'),
  ('Estomatología', 2, 'Realidad Nacional'),
  ('Estomatología', 2, 'Filosofía'),
  ('Estomatología', 3, 'Patología General y Aplicada'),
  ('Estomatología', 3, 'Farmacología General y Aplicada'),
  ('Estomatología', 3, 'Diseño y Modelamiento Dental'),
  ('Estomatología', 3, 'Inglés II'),
  ('Estomatología', 3, 'Interculturalidad'),
  ('Estomatología', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Estomatología', 4, 'Integradora Medicina Estomatológica'),
  ('Estomatología', 4, 'Fisiología del Sistema Estomatognático'),
  ('Estomatología', 4, 'Examenes Auxiliares e Imagenología'),
  ('Estomatología', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Estomatología', 4, 'Carielogía'),
  ('Estomatología', 4, 'Sistematización y Métodos Estadísticos'),
  ('Estomatología', 4, 'Electivo 1'),
  ('Estomatología', 5, 'Periodoncia I'),
  ('Estomatología', 5, 'Endodoncia I'),
  ('Estomatología', 5, 'Simulación en Odontología Restauradora'),
  ('Estomatología', 5, 'Simulación en Prótesis Fija Conservadora'),
  ('Estomatología', 5, 'Estomatología Preventiva'),
  ('Estomatología', 5, 'Metodología de la Investigación'),
  ('Estomatología', 5, 'Electivo 2'),
  ('Estomatología', 6, 'Periodoncia II'),
  ('Estomatología', 6, 'Endodoncia II'),
  ('Estomatología', 6, 'Odontología Estética y Adhesiva'),
  ('Estomatología', 6, 'Prótesis Removible'),
  ('Estomatología', 6, 'Estomatología Pediátrica'),
  ('Estomatología', 6, 'Redacción y Publicación de Artículos I'),
  ('Estomatología', 6, 'Electivo 3'),
  ('Estomatología', 7, 'Cirugía Bucomaxilofacial I'),
  ('Estomatología', 7, 'Clínica Integral del Adulto I'),
  ('Estomatología', 7, 'Clínica Estomatológica Pediátrica I'),
  ('Estomatología', 7, 'Ortodoncia y Ortopedia Maxilar'),
  ('Estomatología', 7, 'Gestión Estratégica y Emprendimiento'),
  ('Estomatología', 7, 'Redacción y Publicación de Artículos II'),
  ('Estomatología', 7, 'Electivo 4'),
  ('Estomatología', 8, 'Cirugía Bucomaxilofacial II'),
  ('Estomatología', 8, 'Clínica Integral del Adulto II'),
  ('Estomatología', 8, 'Clínica Estomatológica Pediátrica II'),
  ('Estomatología', 8, 'Estomatología Legal y Forense'),
  ('Estomatología', 8, 'Atención Integral Estomatológica'),
  ('Estomatología', 8, 'Ética y Profesionalismo'),
  ('Estomatología', 9, 'Internado Quirúrgico Estomatológico I'),
  ('Estomatología', 9, 'Internado Clínico Estomatológico I'),
  ('Estomatología', 9, 'Seminario Multidisciplinario en Estomatología I'),
  ('Estomatología', 9, 'Taller Guía de Proyecto de Tesis'),
  ('Estomatología', 10, 'Internado Quirúrgico Estomatológico II'),
  ('Estomatología', 10, 'Internado Clínico Estomatológico II'),
  ('Estomatología', 10, 'Seminario Multidisciplinario en Estomatología II'),
  ('Estomatología', 10, 'Trabajo de Investigación'),
  ('Ingeniería de Sistemas', 1, 'Introducción a la Ingeniería de Sistemas'),
  ('Ingeniería de Sistemas', 1, 'Geometría Analítica y Álgebra Lineal'),
  ('Ingeniería de Sistemas', 1, 'Creatividad Digital'),
  ('Ingeniería de Sistemas', 1, 'Química'),
  ('Ingeniería de Sistemas', 1, 'Lógico - Matemática'),
  ('Ingeniería de Sistemas', 1, 'Redacción e Interpretación de Textos'),
  ('Ingeniería de Sistemas', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Ingeniería de Sistemas', 2, 'Algorítmica'),
  ('Ingeniería de Sistemas', 2, 'Física I'),
  ('Ingeniería de Sistemas', 2, 'Comunicación y Medios Digitales'),
  ('Ingeniería de Sistemas', 2, 'Realidad Nacional'),
  ('Ingeniería de Sistemas', 2, 'Filosofía'),
  ('Ingeniería de Sistemas', 2, 'Inglés I'),
  ('Ingeniería de Sistemas', 2, 'Cálculo Diferencial'),
  ('Ingeniería de Sistemas', 3, 'Programación Orientado a Objetos'),
  ('Ingeniería de Sistemas', 3, 'Física II'),
  ('Ingeniería de Sistemas', 3, 'Estática'),
  ('Ingeniería de Sistemas', 3, 'Cálculo Integral'),
  ('Ingeniería de Sistemas', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Ingeniería de Sistemas', 3, 'Interculturalidad'),
  ('Ingeniería de Sistemas', 3, 'Inglés II'),
  ('Ingeniería de Sistemas', 4, 'Ingeniería de Software'),
  ('Ingeniería de Sistemas', 4, 'Modelamiento de Base de Datos'),
  ('Ingeniería de Sistemas', 4, 'Taller de Programación Web'),
  ('Ingeniería de Sistemas', 4, 'Cálculo Numérico'),
  ('Ingeniería de Sistemas', 4, 'Estadística Básica I'),
  ('Ingeniería de Sistemas', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Ingeniería de Sistemas', 5, 'Sistemas Operativos'),
  ('Ingeniería de Sistemas', 5, 'Modelamiento de Procesos'),
  ('Ingeniería de Sistemas', 5, 'Contabilidad y Finanzas'),
  ('Ingeniería de Sistemas', 5, 'Estadística Básica II'),
  ('Ingeniería de Sistemas', 5, 'Desarrollo de Aplicaciones Móviles'),
  ('Ingeniería de Sistemas', 5, 'Matemática Computacional'),
  ('Ingeniería de Sistemas', 5, 'Administración de Base de Datos'),
  ('Ingeniería de Sistemas', 6, 'Circuitos y Sistemas Electrónicos'),
  ('Ingeniería de Sistemas', 6, 'Redes y Comunicaciones'),
  ('Ingeniería de Sistemas', 6, 'Costos y Presupuestos'),
  ('Ingeniería de Sistemas', 6, 'Computación Gráfica y Visual'),
  ('Ingeniería de Sistemas', 6, 'Desarrollo de Sistemas Multiplataforma'),
  ('Ingeniería de Sistemas', 6, 'Teoría General de Sistemas'),
  ('Ingeniería de Sistemas', 6, 'Metodología de la Investigación Científica'),
  ('Ingeniería de Sistemas', 7, 'Investigación de Operaciones'),
  ('Ingeniería de Sistemas', 7, 'Sistemas Inteligentes'),
  ('Ingeniería de Sistemas', 7, 'Arquitectura y Sistemas Embebidos'),
  ('Ingeniería de Sistemas', 7, 'Arquitectura Empresarial y Planeamiento Estratégico'),
  ('Ingeniería de Sistemas', 7, 'Dinámica de Sistemas'),
  ('Ingeniería de Sistemas', 7, 'Optimización y Simulación de Sistemas'),
  ('Ingeniería de Sistemas', 7, 'Electivo'),
  ('Ingeniería de Sistemas', 8, 'Arquitectura de Software'),
  ('Ingeniería de Sistemas', 8, 'Big Data y Analytics'),
  ('Ingeniería de Sistemas', 8, 'Metodologías Ágiles'),
  ('Ingeniería de Sistemas', 8, 'Telecomunicaciones y Sistemas Distribuidos'),
  ('Ingeniería de Sistemas', 8, 'Redacción Científica'),
  ('Ingeniería de Sistemas', 8, 'Ética y Profesionalismo'),
  ('Ingeniería de Sistemas', 8, 'Electivo'),
  ('Ingeniería de Sistemas', 9, 'Calidad y Pruebas de Software'),
  ('Ingeniería de Sistemas', 9, 'Sistema de Soporte de Decisiones'),
  ('Ingeniería de Sistemas', 9, 'Gestión de Proyectos'),
  ('Ingeniería de Sistemas', 9, 'Inteligencia Artificial'),
  ('Ingeniería de Sistemas', 9, 'Trabajo de Investigación I'),
  ('Ingeniería de Sistemas', 9, 'Electivo'),
  ('Ingeniería de Sistemas', 10, 'Seguridad de la información y Auditoría de Sistemas'),
  ('Ingeniería de Sistemas', 10, 'Internet de las Cosas y Robótica'),
  ('Ingeniería de Sistemas', 10, 'Redacción y Publicación de Artículos Científicos'),
  ('Ingeniería de Sistemas', 10, 'Trabajo de Investigación II'),
  ('Ingeniería de Sistemas', 10, 'Prácticas Preprofesionales'),
  ('Ingeniería de Sistemas', 10, 'Electivo'),
  ('Turismo, Hotelería y Gastronomía', 1, 'Teoría del Turismo'),
  ('Turismo, Hotelería y Gastronomía', 1, 'Introducción a la Economía'),
  ('Turismo, Hotelería y Gastronomía', 1, 'Herramientas Tecnológicas'),
  ('Turismo, Hotelería y Gastronomía', 1, 'Redacción e Interpretación de textos'),
  ('Turismo, Hotelería y Gastronomía', 1, 'Lógico-Matemática'),
  ('Turismo, Hotelería y Gastronomía', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Turismo, Hotelería y Gastronomía', 2, 'Historia y Geografía Turística Peruana'),
  ('Turismo, Hotelería y Gastronomía', 2, 'Fundamentos y Doctrina Contable'),
  ('Turismo, Hotelería y Gastronomía', 2, 'Comunicación y Medios Digitales'),
  ('Turismo, Hotelería y Gastronomía', 2, 'Realidad Nacional'),
  ('Turismo, Hotelería y Gastronomía', 2, 'Filosofía'),
  ('Turismo, Hotelería y Gastronomía', 2, 'Inglés I'),
  ('Turismo, Hotelería y Gastronomía', 3, 'Gastronomía y Cultura: La Costa'),
  ('Turismo, Hotelería y Gastronomía', 3, 'Fundamentos de la Hotelería'),
  ('Turismo, Hotelería y Gastronomía', 3, 'Legislación Aplicada al Turismo'),
  ('Turismo, Hotelería y Gastronomía', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Turismo, Hotelería y Gastronomía', 3, 'Interculturalidad'),
  ('Turismo, Hotelería y Gastronomía', 3, 'Inglés II'),
  ('Turismo, Hotelería y Gastronomía', 4, 'Gastronomía y Cultura: La Sierra'),
  ('Turismo, Hotelería y Gastronomía', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Turismo, Hotelería y Gastronomía', 4, 'Conocimiento, Tecnología y Globalización'),
  ('Turismo, Hotelería y Gastronomía', 4, 'Modelo de Negocios y Creación de Valor'),
  ('Turismo, Hotelería y Gastronomía', 4, 'Cronistas Históricos y Contemporáneos'),
  ('Turismo, Hotelería y Gastronomía', 4, 'Inglés Técnico I'),
  ('Turismo, Hotelería y Gastronomía', 5, 'Gastronomía y Cultura: La Selva'),
  ('Turismo, Hotelería y Gastronomía', 5, 'Turismo de Inmersión Cultural'),
  ('Turismo, Hotelería y Gastronomía', 5, 'Gestión del Patrimonio Cultural'),
  ('Turismo, Hotelería y Gastronomía', 5, 'Gerencia de Costos y Presupuestos en Turismo'),
  ('Turismo, Hotelería y Gastronomía', 5, 'Inglés Técnico II'),
  ('Turismo, Hotelería y Gastronomía', 5, 'Electivo I'),
  ('Turismo, Hotelería y Gastronomía', 6, 'Gastronomía y Cultura: Tendencias de la Cocina Global'),
  ('Turismo, Hotelería y Gastronomía', 6, 'Gestión Logística Hotelera'),
  ('Turismo, Hotelería y Gastronomía', 6, 'Introducción al Marketing'),
  ('Turismo, Hotelería y Gastronomía', 6, 'Biodiversidad y Ecoturismo'),
  ('Turismo, Hotelería y Gastronomía', 6, 'Metodología de la Investigación Científica'),
  ('Turismo, Hotelería y Gastronomía', 6, 'Electivo II'),
  ('Turismo, Hotelería y Gastronomía', 7, 'Enología y Cocktails'),
  ('Turismo, Hotelería y Gastronomía', 7, 'Gestión de la Calidad'),
  ('Turismo, Hotelería y Gastronomía', 7, 'Comportamiento del Consumidor'),
  ('Turismo, Hotelería y Gastronomía', 7, 'Circuitos y Paquetes Turísticos'),
  ('Turismo, Hotelería y Gastronomía', 7, 'Redacción Científica'),
  ('Turismo, Hotelería y Gastronomía', 7, 'Electivo III'),
  ('Turismo, Hotelería y Gastronomía', 8, 'Comercialización Turística'),
  ('Turismo, Hotelería y Gastronomía', 8, 'Investigación de Mercado'),
  ('Turismo, Hotelería y Gastronomía', 8, 'Gestión de Proyectos'),
  ('Turismo, Hotelería y Gastronomía', 8, 'Estadística Básica'),
  ('Turismo, Hotelería y Gastronomía', 8, 'Ética y Profesionalismo'),
  ('Turismo, Hotelería y Gastronomía', 8, 'Electivo IV'),
  ('Turismo, Hotelería y Gastronomía', 9, 'Innovación y Diseño de Servicios Turísticos'),
  ('Turismo, Hotelería y Gastronomía', 9, 'Diseño de Cartas y Maridaje'),
  ('Turismo, Hotelería y Gastronomía', 9, 'Infraestructura y Equipamiento Hotelero'),
  ('Turismo, Hotelería y Gastronomía', 9, 'Análisis de Datos y Sistemas de información Gerencial'),
  ('Turismo, Hotelería y Gastronomía', 9, 'Gestión Estratégica Empresarial'),
  ('Turismo, Hotelería y Gastronomía', 9, 'Trabajo de Investigación I'),
  ('Turismo, Hotelería y Gastronomía', 10, 'Prácticas Pre Profesionales'),
  ('Turismo, Hotelería y Gastronomía', 10, 'Taller de HouseKeeping'),
  ('Turismo, Hotelería y Gastronomía', 10, 'Innovación en la Experiencia Digital del Turista'),
  ('Turismo, Hotelería y Gastronomía', 10, 'Trabajo de Investigación II'),
  ('Medicina Veterinaria y Zootecnia', 1, 'Biología Molecular'),
  ('Medicina Veterinaria y Zootecnia', 1, 'Embriología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 1, 'Ecología y Medio Ambiente'),
  ('Medicina Veterinaria y Zootecnia', 1, 'Bioquímica'),
  ('Medicina Veterinaria y Zootecnia', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Medicina Veterinaria y Zootecnia', 1, 'Lógico-Matemática'),
  ('Medicina Veterinaria y Zootecnia', 1, 'Redacción e Interpretación de Textos'),
  ('Medicina Veterinaria y Zootecnia', 2, 'Anatomía Animal I'),
  ('Medicina Veterinaria y Zootecnia', 2, 'Histología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 2, 'Zootecnia'),
  ('Medicina Veterinaria y Zootecnia', 2, 'Comunicación y Medios Digitales'),
  ('Medicina Veterinaria y Zootecnia', 2, 'Realidad Nacional'),
  ('Medicina Veterinaria y Zootecnia', 2, 'Filosofía'),
  ('Medicina Veterinaria y Zootecnia', 2, 'Inglés I'),
  ('Medicina Veterinaria y Zootecnia', 3, 'Anatomía Animal II'),
  ('Medicina Veterinaria y Zootecnia', 3, 'Bacteriología y Micología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 3, 'Virología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 3, 'Semiología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 3, 'Interculturalidad'),
  ('Medicina Veterinaria y Zootecnia', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Medicina Veterinaria y Zootecnia', 3, 'Inglés II'),
  ('Medicina Veterinaria y Zootecnia', 4, 'Fisiología Animal'),
  ('Medicina Veterinaria y Zootecnia', 4, 'Genética'),
  ('Medicina Veterinaria y Zootecnia', 4, 'Enfermedades Parasitarias'),
  ('Medicina Veterinaria y Zootecnia', 4, 'Producción de Forrajes'),
  ('Medicina Veterinaria y Zootecnia', 4, 'Medicina Preventiva Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Medicina Veterinaria y Zootecnia', 4, 'Etología y Bienestar Animal'),
  ('Medicina Veterinaria y Zootecnia', 5, 'Patología Aviar'),
  ('Medicina Veterinaria y Zootecnia', 5, 'Inmunología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 5, 'Enfermedades Infecciosas'),
  ('Medicina Veterinaria y Zootecnia', 5, 'Reproducción Animal'),
  ('Medicina Veterinaria y Zootecnia', 5, 'Nutrición y Alimentación Animal'),
  ('Medicina Veterinaria y Zootecnia', 5, 'Sistematización y Métodos Estadísticos'),
  ('Medicina Veterinaria y Zootecnia', 5, 'Electivo I'),
  ('Medicina Veterinaria y Zootecnia', 6, 'Patología Clínica'),
  ('Medicina Veterinaria y Zootecnia', 6, 'Farmacología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 6, 'Patología General Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 6, 'Mejoramiento Genético'),
  ('Medicina Veterinaria y Zootecnia', 6, 'Bioética y Legislación Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 6, 'Metodología de la Investigación'),
  ('Medicina Veterinaria y Zootecnia', 6, 'Electivo II'),
  ('Medicina Veterinaria y Zootecnia', 7, 'Medicina de Animales Menores'),
  ('Medicina Veterinaria y Zootecnia', 7, 'Toxicología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 7, 'Gestión Integral Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 7, 'Sanidad y Producción Porcina'),
  ('Medicina Veterinaria y Zootecnia', 7, 'Epidemiología Veterinaria'),
  ('Medicina Veterinaria y Zootecnia', 7, 'Redacción y Publicación de Artículos Científicos I'),
  ('Medicina Veterinaria y Zootecnia', 7, 'Electivo III'),
  ('Medicina Veterinaria y Zootecnia', 8, 'Medicina de Animales Mayores'),
  ('Medicina Veterinaria y Zootecnia', 8, 'Cirugía de Animales Menores'),
  ('Medicina Veterinaria y Zootecnia', 8, 'Producción de Rumiantes Menores y Mayores'),
  ('Medicina Veterinaria y Zootecnia', 8, 'Producción de Equinos'),
  ('Medicina Veterinaria y Zootecnia', 8, 'Inocuidad y Seguridad Alimentaria'),
  ('Medicina Veterinaria y Zootecnia', 8, 'Redacción y Publicación de Artículos Científicos II'),
  ('Medicina Veterinaria y Zootecnia', 8, 'Ética y Profesionalismo'),
  ('Medicina Veterinaria y Zootecnia', 9, 'Cirugía de Animales Mayores'),
  ('Medicina Veterinaria y Zootecnia', 9, 'Producción y Sanidad de Hidrobiológicos'),
  ('Medicina Veterinaria y Zootecnia', 9, 'Sanidad y Producción Avícola'),
  ('Medicina Veterinaria y Zootecnia', 9, 'Sanidad y Producción Apícola'),
  ('Medicina Veterinaria y Zootecnia', 9, 'Manejo y Enfermedades de Fauna Silvestre'),
  ('Medicina Veterinaria y Zootecnia', 9, 'Taller Guía de Proyectos de Tesis'),
  ('Medicina Veterinaria y Zootecnia', 9, 'Electivo IV'),
  ('Medicina Veterinaria y Zootecnia', 10, 'Internado Animales Mayores y Menores'),
  ('Medicina Veterinaria y Zootecnia', 10, 'Internado Producción Animal'),
  ('Medicina Veterinaria y Zootecnia', 10, 'Internado Inocuidad y Salud Pública'),
  ('Medicina Veterinaria y Zootecnia', 10, 'Trabajo de Investigación'),
  ('Psicología', 1, 'Historia y Teorías Psicológicas Contemporáneas'),
  ('Psicología', 1, 'Correlatos Biológicos del Comportamiento Humano'),
  ('Psicología', 1, 'Psicología General'),
  ('Psicología', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Psicología', 1, 'Lógico-Matemática'),
  ('Psicología', 1, 'Redacción e Interpretación de Textos'),
  ('Psicología', 2, 'Psicología y Evaluación de los Procesos Cognitivos'),
  ('Psicología', 2, 'Neuroanatomía y Neurofisiología'),
  ('Psicología', 2, 'Psicología y Evaluación del Desarrollo Humano I'),
  ('Psicología', 2, 'Realidad Nacional'),
  ('Psicología', 2, 'Filosofía'),
  ('Psicología', 2, 'Inglés I'),
  ('Psicología', 2, 'Comunicación y Medios Digitales'),
  ('Psicología', 3, 'Métodos de Entrevista y Observación'),
  ('Psicología', 3, 'Psicología, Teorías y Evaluación de la Personalidad'),
  ('Psicología', 3, 'Psicología y Evaluación del Desarrollo Humano II'),
  ('Psicología', 3, 'Interculturalidad'),
  ('Psicología', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Psicología', 3, 'Inglés II'),
  ('Psicología', 3, 'Psicología y Evaluación de la Inteligencia y Funciones Ejecutivas'),
  ('Psicología', 4, 'Pruebas y Evaluación Psicológica'),
  ('Psicología', 4, 'Psicopatología y Psicofarmacología'),
  ('Psicología', 4, 'Psicología y Evaluación de los Procesos Emocionales y Motivacionales'),
  ('Psicología', 4, 'Neurociencias del Comportamiento'),
  ('Psicología', 4, 'Sistematización y Métodos Estadísticos'),
  ('Psicología', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Psicología', 4, 'Electivo 1'),
  ('Psicología', 5, 'Psicopatología de la Afectividad y Sexualidad'),
  ('Psicología', 5, 'Diagnóstico e Informe Clínico Psicopatológico'),
  ('Psicología', 5, 'Taller de Evaluación e Informe de pruebas proyectivas'),
  ('Psicología', 5, 'Psicología Social y Comunitaria'),
  ('Psicología', 5, 'Metodología de la Investigación'),
  ('Psicología', 5, 'Diseño y Construcción de instrumentos psicológicos'),
  ('Psicología', 5, 'Electivo 2'),
  ('Psicología', 6, 'Psicología de la Salud y estilos de vida saludables'),
  ('Psicología', 6, 'Integradora: Externado I Evaluación y Diagnóstico'),
  ('Psicología', 6, 'Psicología Educativa y del Aprendizaje'),
  ('Psicología', 6, 'Psicología Organizacional'),
  ('Psicología', 6, 'Redacción y Publicación de artículos científicos I'),
  ('Psicología', 6, 'Inglés Técnico I'),
  ('Psicología', 6, 'Electivo 3'),
  ('Psicología', 7, 'Psicoterapia I'),
  ('Psicología', 7, 'Psicología Forense y Criminalística Contemporánea'),
  ('Psicología', 7, 'Intervención en las Personas con discapacidad'),
  ('Psicología', 7, 'Intervención en Emergencias y Desastres'),
  ('Psicología', 7, 'Redacción y Publicación de Artículos Científicos II'),
  ('Psicología', 7, 'Inglés Técnico II'),
  ('Psicología', 7, 'Electivo 4'),
  ('Psicología', 8, 'Psicoterapia II'),
  ('Psicología', 8, 'Integradora: Externado II'),
  ('Psicología', 8, 'Intervención, Prevención y Promoción'),
  ('Psicología', 8, 'Diagnóstico e Intervención Educacional'),
  ('Psicología', 8, 'Gestión del Talento Humano'),
  ('Psicología', 8, 'Ética y Profesionalismo'),
  ('Psicología', 9, 'Primera Rotación de Internado'),
  ('Psicología', 9, 'Segunda Rotación de internado'),
  ('Psicología', 9, 'Taller Guía de Proyecto de Tesis'),
  ('Psicología', 10, 'Tercera Rotación de Internado'),
  ('Psicología', 10, 'Cuarta Rotación de Internado'),
  ('Psicología', 10, 'Trabajo de Investigación'),
  ('Ingeniería Civil', 1, 'Geología General'),
  ('Ingeniería Civil', 1, 'Introducción a la Ingeniería Civil'),
  ('Ingeniería Civil', 1, 'Química'),
  ('Ingeniería Civil', 1, 'Geometría Analítica y Álgebra lineal'),
  ('Ingeniería Civil', 1, 'Lógico-Matemática'),
  ('Ingeniería Civil', 1, 'Redacción e Interpretación de Textos'),
  ('Ingeniería Civil', 1, 'Vida Universitaria y Gestión del Conocimiento'),
  ('Ingeniería Civil', 2, 'Tecnología de los Materiales y del Concreto'),
  ('Ingeniería Civil', 2, 'Física I'),
  ('Ingeniería Civil', 2, 'Cálculo Diferencial'),
  ('Ingeniería Civil', 2, 'Comunicación y Medios Digitales'),
  ('Ingeniería Civil', 2, 'Realidad Nacional'),
  ('Ingeniería Civil', 2, 'Filosofía'),
  ('Ingeniería Civil', 2, 'Inglés I'),
  ('Ingeniería Civil', 3, 'Diseño Gráfico de Ingeniería I'),
  ('Ingeniería Civil', 3, 'Física II'),
  ('Ingeniería Civil', 3, 'Estática'),
  ('Ingeniería Civil', 3, 'Cálculo Integral'),
  ('Ingeniería Civil', 3, 'Pensamiento Crítico, Creativo y Emprendimiento'),
  ('Ingeniería Civil', 3, 'Interculturalidad'),
  ('Ingeniería Civil', 3, 'Inglés II'),
  ('Ingeniería Civil', 4, 'Diseño Gráfico de Ingeniería II'),
  ('Ingeniería Civil', 4, 'Topografía'),
  ('Ingeniería Civil', 4, 'Resistencia de Materiales I'),
  ('Ingeniería Civil', 4, 'Dinámica'),
  ('Ingeniería Civil', 4, 'Cálculo Numérico'),
  ('Ingeniería Civil', 4, 'Estadística Básica I'),
  ('Ingeniería Civil', 4, 'Ciudadanía Global y Desarrollo Sostenible'),
  ('Ingeniería Civil', 5, 'Geodesia Satelital'),
  ('Ingeniería Civil', 5, 'Mecánica de Suelos I'),
  ('Ingeniería Civil', 5, 'Resistencia de Materiales II'),
  ('Ingeniería Civil', 5, 'Estructuras y Cargas'),
  ('Ingeniería Civil', 5, 'Construcción I'),
  ('Ingeniería Civil', 5, 'Curso Integrador de Ingeniería Civil I'),
  ('Ingeniería Civil', 5, 'Estadística Básica II'),
  ('Ingeniería Civil', 6, 'Caminos'),
  ('Ingeniería Civil', 6, 'Mecánica de Suelos II'),
  ('Ingeniería Civil', 6, 'Mecánica de Fluidos'),
  ('Ingeniería Civil', 6, 'Análisis Estructural I'),
  ('Ingeniería Civil', 6, 'Construcción II'),
  ('Ingeniería Civil', 6, 'Instalaciones Eléctricas, Sanitarias, de Gas y Electromecánicas'),
  ('Ingeniería Civil', 6, 'Metodología de la Investigación'),
  ('Ingeniería Civil', 7, 'Pavimentos'),
  ('Ingeniería Civil', 7, 'Hidrología General'),
  ('Ingeniería Civil', 7, 'Hidráulica de Canales y Tuberías'),
  ('Ingeniería Civil', 7, 'Concreto Armado I'),
  ('Ingeniería Civil', 7, 'Análisis Estructural II'),
  ('Ingeniería Civil', 7, 'Elaboración y Evaluación de Proyectos en Ingeniería'),
  ('Ingeniería Civil', 7, 'Redacción Científica'),
  ('Ingeniería Civil', 8, 'Curso Integrador de Ingeniería Civil II'),
  ('Ingeniería Civil', 8, 'Costos, Presupuestos y Programación de Obras'),
  ('Ingeniería Civil', 8, 'Agua y Alcantarillado'),
  ('Ingeniería Civil', 8, 'Concreto Armado II'),
  ('Ingeniería Civil', 8, 'Vulnerabilidad e Ingeniería Sismorresistente'),
  ('Ingeniería Civil', 8, 'Ética y Profesionalismo'),
  ('Ingeniería Civil', 8, 'Diseño de Experimentos y Herramientas para la Investigación'),
  ('Ingeniería Civil', 9, 'Obras Hidráulicas'),
  ('Ingeniería Civil', 9, 'Puentes y Obras de Arte'),
  ('Ingeniería Civil', 9, 'Diseño en Acero y Madera'),
  ('Ingeniería Civil', 9, 'Legislación para la Ingeniería Civil'),
  ('Ingeniería Civil', 9, 'Trabajo de Investigación I'),
  ('Ingeniería Civil', 9, 'Electivo I'),
  ('Ingeniería Civil', 9, 'Electivo II'),
  ('Ingeniería Civil', 10, 'Curso Integrador de Ingeniería Civil III'),
  ('Ingeniería Civil', 10, 'Prácticas Preprofesionales'),
  ('Ingeniería Civil', 10, 'Gestión de la Calidad y Productividad en la Construcción'),
  ('Ingeniería Civil', 10, 'Trabajo de Investigación II'),
  ('Ingeniería Civil', 10, 'Electivo I'),
  ('Ingeniería Civil', 10, 'Electivo II');

drop table if exists tmp_career_alias_upsjb;
create temp table tmp_career_alias_upsjb (
  official_career text not null,
  career_alias text not null
);

insert into tmp_career_alias_upsjb (official_career, career_alias)
values
  ('Administración de Empresas', 'Administración de Empresas'),
  ('Administración de Empresas', 'Administracion de Empresas'),
  ('Administración de Empresas', 'Administración'),
  ('Administración de Empresas', 'Administracion'),
  ('Derecho', 'Derecho'),
  ('Contabilidad', 'Contabilidad'),
  ('Administración y Marketing', 'Administración y Marketing'),
  ('Administración y Marketing', 'Administracion y Marketing'),
  ('Enfermería', 'Enfermería'),
  ('Enfermería', 'Enfermeria'),
  ('Ingeniería Agroindustrial', 'Ingeniería Agroindustrial'),
  ('Ingeniería Agroindustrial', 'Ingenieria Agroindustrial'),
  ('Ingeniería en Enología y Viticultura', 'Ingeniería en Enología y Viticultura'),
  ('Ingeniería en Enología y Viticultura', 'Ingenieria en Enologia y Viticultura'),
  ('Ingeniería en Enología y Viticultura', 'Enología y Viticultura'),
  ('Ingeniería en Enología y Viticultura', 'Enologia y Viticultura'),
  ('Medicina Humana', 'Medicina Humana'),
  ('Laboratorio Clínico y Anatomía Patológica', 'Laboratorio Clínico y Anatomía Patológica'),
  ('Laboratorio Clínico y Anatomía Patológica', 'Laboratorio Clinico y Anatomia Patologica'),
  ('Laboratorio Clínico y Anatomía Patológica', 'Tecnología Médica - Laboratorio Clínico y Anatomía Patológica'),
  ('Laboratorio Clínico y Anatomía Patológica', 'Tecnologia Medica Laboratorio Clinico y Anatomia Patologica'),
  ('Laboratorio Clínico y Anatomía Patológica', 'Tecnología Médica: Laboratorio Clínico y Anatomía Patológica'),
  ('Terapia Física y Rehabilitación', 'Terapia Física y Rehabilitación'),
  ('Terapia Física y Rehabilitación', 'Terapia Fisica y Rehabilitacion'),
  ('Terapia Física y Rehabilitación', 'Tecnología Médica - Terapia Física y Rehabilitación'),
  ('Terapia Física y Rehabilitación', 'Tecnologia Medica Terapia Fisica y Rehabilitacion'),
  ('Estomatología', 'Estomatología'),
  ('Estomatología', 'Estomatologia'),
  ('Ingeniería de Sistemas', 'Ingeniería de Sistemas'),
  ('Ingeniería de Sistemas', 'Ingenieria de Sistemas'),
  ('Turismo, Hotelería y Gastronomía', 'Turismo, Hotelería y Gastronomía'),
  ('Turismo, Hotelería y Gastronomía', 'Turismo Hotelería y Gastronomía'),
  ('Turismo, Hotelería y Gastronomía', 'Turismo, Hoteleria y Gastronomia'),
  ('Turismo, Hotelería y Gastronomía', 'Turismo Hoteleria y Gastronomia'),
  ('Medicina Veterinaria y Zootecnia', 'Medicina Veterinaria y Zootecnia'),
  ('Psicología', 'Psicología'),
  ('Psicología', 'Psicologia'),
  ('Ingeniería Civil', 'Ingeniería Civil'),
  ('Ingeniería Civil', 'Ingenieria Civil');

-- ============================================================
-- CONFIGURACIÓN
-- Cambia UPSJB por el código real de tu tabla public.universities si fuera distinto.
-- ============================================================
drop table if exists tmp_config_upsjb;
create temp table tmp_config_upsjb as
select 'UPSJB'::text as university_code;

-- ============================================================
-- 0.1 Asegurar estructura académica UPSJB
-- Si faltan facultades/carreras en la BD, se crean antes de cargar cursos.
-- Relación usada: universities -> faculties -> careers.
-- ============================================================

insert into public.universities (name, code, status)
select 'Universidad Privada San Juan Bautista', (select university_code from tmp_config_upsjb), 'active'
where not exists (
  select 1 from public.universities u
  where public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
);

update public.universities
set status = 'active'
where public.mn_normalize(code) = public.mn_normalize((select university_code from tmp_config_upsjb));

drop table if exists tmp_career_faculty_upsjb;
create temp table tmp_career_faculty_upsjb (
  career_name text not null,
  faculty_name text not null
);

insert into tmp_career_faculty_upsjb (career_name, faculty_name)
values
  ('Administración de Empresas', 'Facultad de Ciencias Empresariales'),
  ('Administración y Marketing', 'Facultad de Ciencias Empresariales'),
  ('Contabilidad', 'Facultad de Ciencias Empresariales'),
  ('Turismo, Hotelería y Gastronomía', 'Facultad de Ciencias Empresariales'),
  ('Derecho', 'Facultad de Derecho'),
  ('Ingeniería de Sistemas', 'Facultad de Ingenierías'),
  ('Ingeniería Civil', 'Facultad de Ingenierías'),
  ('Ingeniería Agroindustrial', 'Facultad de Ingenierías'),
  ('Ingeniería en Enología y Viticultura', 'Facultad de Ingenierías'),
  ('Enfermería', 'Facultad de Ciencias de la Salud'),
  ('Medicina Humana', 'Facultad de Ciencias de la Salud'),
  ('Laboratorio Clínico y Anatomía Patológica', 'Facultad de Ciencias de la Salud'),
  ('Terapia Física y Rehabilitación', 'Facultad de Ciencias de la Salud'),
  ('Estomatología', 'Facultad de Ciencias de la Salud'),
  ('Psicología', 'Facultad de Ciencias de la Salud'),
  ('Medicina Veterinaria y Zootecnia', 'Facultad de Ciencias de la Salud');

-- Crear facultades faltantes en UPSJB.
with u as (
  select id from public.universities
  where public.mn_normalize(code) = public.mn_normalize((select university_code from tmp_config_upsjb))
  limit 1
), faculties_to_create as (
  select distinct faculty_name from tmp_career_faculty_upsjb
)
insert into public.faculties (university_id, name, status)
select u.id, f.faculty_name, 'active'
from u
cross join faculties_to_create f
where not exists (
  select 1
  from public.faculties fx
  where fx.university_id = u.id
    and public.mn_normalize(fx.name) = public.mn_normalize(f.faculty_name)
);

-- Reactivar facultades UPSJB usadas por la malla.
update public.faculties f
set status = 'active'
from public.universities u, tmp_career_faculty_upsjb m
where f.university_id = u.id
  and public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
  and public.mn_normalize(f.name) = public.mn_normalize(m.faculty_name);

-- Crear carreras faltantes. No duplica si la carrera ya existe en otra facultad de la misma universidad.
with u as (
  select id from public.universities
  where public.mn_normalize(code) = public.mn_normalize((select university_code from tmp_config_upsjb))
  limit 1
), resolved as (
  select
    f.id as faculty_id,
    m.career_name
  from tmp_career_faculty_upsjb m
  join u on true
  join public.faculties f
    on f.university_id = u.id
   and public.mn_normalize(f.name) = public.mn_normalize(m.faculty_name)
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select r.faculty_id, r.career_name, 'active', now(), now()
from resolved r
where not exists (
  select 1
  from public.careers c
  join public.faculties f on f.id = c.faculty_id
  join public.universities u on u.id = f.university_id
  where public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
    and public.mn_normalize(c.name) = public.mn_normalize(r.career_name)
);

-- Reactivar carreras oficiales UPSJB aunque ya existan.
update public.careers c
set status = 'active',
    updated_at = now()
from public.faculties f
join public.universities u on u.id = f.university_id,
     tmp_career_faculty_upsjb m
where c.faculty_id = f.id
  and public.mn_normalize(m.career_name) = public.mn_normalize(c.name)
  and public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb));

-- ============================================================
-- 1) PREVISUALIZACIÓN / VALIDACIÓN
-- ============================================================

-- 1.1 Carreras de la malla que no se encuentran en tu BD.
-- Si trae datos, crea/renombra esas carreras antes de aplicar.
select distinct
  t.career_name as carrera_en_malla
from tmp_malla_cursos_upsjb t
where not exists (
  select 1
  from tmp_career_alias_upsjb a
  join public.universities u
    on public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
  join public.careers ca
    on public.mn_normalize(ca.name) = public.mn_normalize(a.career_alias)
  join public.faculties f
    on f.id = ca.faculty_id
   and f.university_id = u.id
  where a.official_career = t.career_name
)
order by 1;

-- 1.2 Ciclos de la malla que no se encuentran en tu BD.
-- Deben existir ciclos del I al XIV si vas a cargar Medicina Humana completa.
select distinct
  t.cycle_order as ciclo_en_malla
from tmp_malla_cursos_upsjb t
where not exists (
  select 1
  from public.cycles cy
  where cy.order_number = t.cycle_order
)
order by 1;

-- 1.3 Cursos oficiales que faltan en tu BD y serían insertados.
with target as (
  select distinct
    u.id as university_id,
    ca.id as career_id,
    ca.name as db_career_name,
    cy.id as cycle_id,
    cy.name as db_cycle_name,
    t.cycle_order,
    t.course_name
  from tmp_malla_cursos_upsjb t
  join tmp_career_alias_upsjb a on a.official_career = t.career_name
  join public.universities u
    on public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
  join public.careers ca
    on public.mn_normalize(ca.name) = public.mn_normalize(a.career_alias)
  join public.faculties f
    on f.id = ca.faculty_id
   and f.university_id = u.id
  join public.cycles cy
    on cy.order_number = t.cycle_order
)
select
  db_career_name as carrera,
  db_cycle_name as ciclo,
  cycle_order,
  course_name as curso_faltante
from target t
where not exists (
  select 1
  from public.courses c
  where c.university_id = t.university_id
    and c.career_id = t.career_id
    and c.cycle_id = t.cycle_id
    and public.mn_normalize(c.name) = public.mn_normalize(t.course_name)
)
order by carrera, cycle_order, curso_faltante;

-- 1.4 Cursos existentes que NO coinciden con la malla y serían dados de baja.
with official as (
  select distinct
    u.id as university_id,
    ca.id as career_id,
    cy.id as cycle_id,
    public.mn_normalize(t.course_name) as norm_course_name
  from tmp_malla_cursos_upsjb t
  join tmp_career_alias_upsjb a on a.official_career = t.career_name
  join public.universities u
    on public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
  join public.careers ca
    on public.mn_normalize(ca.name) = public.mn_normalize(a.career_alias)
  join public.faculties f
    on f.id = ca.faculty_id
   and f.university_id = u.id
  join public.cycles cy
    on cy.order_number = t.cycle_order
), scoped_careers as (
  select distinct university_id, career_id from official
)
select
  ca.name as carrera,
  cy.name as ciclo,
  cy.order_number,
  c.name as curso_actual_bd,
  c.status
from public.courses c
join public.universities u on u.id = c.university_id
join public.careers ca on ca.id = c.career_id
join public.cycles cy on cy.id = c.cycle_id
join scoped_careers sc on sc.university_id = c.university_id and sc.career_id = c.career_id
where public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
  and not exists (
    select 1
    from official o
    where o.university_id = c.university_id
      and o.career_id = c.career_id
      and o.cycle_id = c.cycle_id
      and o.norm_course_name = public.mn_normalize(c.name)
  )
order by carrera, cy.order_number, curso_actual_bd;

-- ============================================================
-- 2) APLICAR CAMBIOS: INSERTAR / REACTIVAR / DAR DE BAJA
-- Ejecuta desde aquí solo después de revisar la previsualización.
-- ============================================================

begin;

-- 2.1 Detener si faltan carreras o ciclos.
do $$
begin
  if exists (
    select 1
    from tmp_malla_cursos_upsjb t
    where not exists (
      select 1
      from tmp_career_alias_upsjb a
      join public.universities u
        on public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
      join public.careers ca
        on public.mn_normalize(ca.name) = public.mn_normalize(a.career_alias)
      join public.faculties f
        on f.id = ca.faculty_id
       and f.university_id = u.id
      where a.official_career = t.career_name
    )
  ) then
    raise exception 'Hay carreras de la malla que no existen en public.careers. Revisa la consulta 1.1.';
  end if;

  if exists (
    select 1
    from tmp_malla_cursos_upsjb t
    where not exists (
      select 1 from public.cycles cy where cy.order_number = t.cycle_order
    )
  ) then
    raise exception 'Hay ciclos de la malla que no existen en public.cycles. Revisa la consulta 1.2.';
  end if;
end $$;

-- 2.2 Crear tabla resuelta temporal.
-- Se elimina duplicidad por contexto + nombre normalizado para evitar conflictos
-- con el índice único courses_context_cycle_name_unique.
drop table if exists tmp_target_courses_upsjb_raw;
create temp table tmp_target_courses_upsjb_raw as
select
  u.id as university_id,
  ca.faculty_id as faculty_id,
  ca.id as career_id,
  cy.id as cycle_id,
  t.career_name,
  t.cycle_order,
  t.course_name,
  public.mn_normalize(t.course_name) as norm_course_name,
  lower(trim(t.course_name)) as lower_course_name
from tmp_malla_cursos_upsjb t
join tmp_career_alias_upsjb a on a.official_career = t.career_name
join public.universities u
  on public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
join public.careers ca
  on public.mn_normalize(ca.name) = public.mn_normalize(a.career_alias)
join public.faculties f
  on f.id = ca.faculty_id
 and f.university_id = u.id
join public.cycles cy
  on cy.order_number = t.cycle_order;

drop table if exists tmp_target_courses_upsjb;
create temp table tmp_target_courses_upsjb as
select distinct on (university_id, faculty_id, career_id, cycle_id, norm_course_name)
  university_id,
  faculty_id,
  career_id,
  cycle_id,
  career_name,
  cycle_order,
  course_name,
  norm_course_name,
  lower_course_name
from tmp_target_courses_upsjb_raw
order by university_id, faculty_id, career_id, cycle_id, norm_course_name, course_name;

-- 2.3 Reactivar/renombrar cursos oficiales que ya existen.
-- Coincide por contexto completo y nombre normalizado:
--   - ignora mayúsculas/minúsculas
--   - normaliza tildes, ñ y espacios
-- Si hay historial/notas, se conserva el mismo ID del curso.
update public.courses c
set
  name = t.course_name,
  faculty_id = t.faculty_id,
  status = 'active',
  updated_at = now()
from tmp_target_courses_upsjb t
where c.university_id = t.university_id
  and c.faculty_id = t.faculty_id
  and c.career_id = t.career_id
  and c.cycle_id = t.cycle_id
  and (
    public.mn_normalize(c.name) = t.norm_course_name
    or lower(trim(c.name)) = t.lower_course_name
  )
  and not exists (
    select 1
    from public.courses other
    where other.id <> c.id
      and other.university_id = t.university_id
      and other.faculty_id = t.faculty_id
      and other.career_id = t.career_id
      and other.cycle_id = t.cycle_id
      and lower(trim(other.name)) = t.lower_course_name
  )
  and (
    c.name is distinct from t.course_name
    or coalesce(c.status, '') <> 'active'
    or c.faculty_id is distinct from t.faculty_id
  );

-- 2.4 Insertar solo los cursos oficiales que realmente no existen.
-- No filtra por status, porque un curso inactive también debe reactivarse,
-- no insertarse nuevamente.
insert into public.courses (
  university_id,
  faculty_id,
  career_id,
  cycle_id,
  name,
  status,
  created_at,
  updated_at
)
select
  t.university_id,
  t.faculty_id,
  t.career_id,
  t.cycle_id,
  t.course_name,
  'active',
  now(),
  now()
from tmp_target_courses_upsjb t
where not exists (
  select 1
  from public.courses c
  where c.university_id = t.university_id
    and c.faculty_id = t.faculty_id
    and c.career_id = t.career_id
    and c.cycle_id = t.cycle_id
    and (
      public.mn_normalize(c.name) = t.norm_course_name
      or lower(trim(c.name)) = t.lower_course_name
    )
)
on conflict do nothing;

-- 2.5 Dar de baja lógica a cursos que NO coinciden con las mallas oficiales.
with scoped_careers as (
  select distinct university_id, career_id
  from tmp_target_courses_upsjb
)
update public.courses c
set
  status = 'inactive',
  updated_at = now()
from scoped_careers sc
where c.university_id = sc.university_id
  and c.career_id = sc.career_id
  and not exists (
    select 1
    from tmp_target_courses_upsjb t
    where t.university_id = c.university_id
      and t.career_id = c.career_id
      and t.cycle_id = c.cycle_id
      and public.mn_normalize(t.course_name) = public.mn_normalize(c.name)
  )
  and coalesce(c.status, '') <> 'inactive';

commit;

-- ============================================================
-- 3) VALIDACIÓN FINAL
-- ============================================================
select
  ca.name as carrera,
  cy.name as ciclo,
  cy.order_number,
  count(*) filter (where c.status = 'active') as cursos_activos,
  count(*) filter (where c.status = 'inactive') as cursos_inactivos
from public.courses c
join public.universities u on u.id = c.university_id
join public.careers ca on ca.id = c.career_id
join public.cycles cy on cy.id = c.cycle_id
where public.mn_normalize(u.code) = public.mn_normalize((select university_code from tmp_config_upsjb))
group by ca.name, cy.name, cy.order_number
order by ca.name, cy.order_number;

-- ============================================================
-- 4) OPCIONAL: BORRADO FÍSICO DE CURSOS SOBRANTES SIN USO
-- NO recomendado si existen notas o historial.
-- Descomenta SOLO si quieres eliminar físicamente cursos sin referencias.
-- ============================================================
/*
begin;

with official as (
  select distinct
    university_id,
    career_id,
    cycle_id,
    public.mn_normalize(course_name) as norm_course_name
  from tmp_target_courses_upsjb
), scoped_careers as (
  select distinct university_id, career_id
  from tmp_target_courses_upsjb
), sobrantes as (
  select c.id
  from public.courses c
  join scoped_careers sc on sc.university_id = c.university_id and sc.career_id = c.career_id
  where not exists (
    select 1
    from official o
    where o.university_id = c.university_id
      and o.career_id = c.career_id
      and o.cycle_id = c.cycle_id
      and o.norm_course_name = public.mn_normalize(c.name)
  )
  and not exists (select 1 from public.course_grades cg where cg.course_id = c.id)
  and not exists (select 1 from public.calculation_history ch where ch.course_id = c.id)
)
delete from public.courses c
using sobrantes s
where c.id = s.id;

commit;
*/


-- ============================================================
-- BLOQUE 2: UAI
-- ============================================================

-- ============================================================
-- MI NOTA FINAL - VALIDAR Y SINCRONIZAR MALLAS UAI SEGUN BROCHURES
-- MODO APLICAR: inserta/reactiva cursos UAI y da de baja lógica a cursos no oficiales.
-- Este script sincroniza SOLO las carreras que tienen brochure cargado en esta revisión.
-- Las carreras sin PDF aquí (por ejemplo Administración y Finanzas u Optometría) NO se limpian.
-- ============================================================

begin;

create temporary table tmp_config(do_apply boolean not null);
insert into tmp_config values (true); -- APLICAR CAMBIOS

create extension if not exists pgcrypto;

create or replace function public.mnf_norm(value text)
returns text
language sql
immutable
as $$
  select trim(regexp_replace(lower(translate(coalesce(value,''), 'ÁÉÍÓÚÜÑáéíóúüñ–—', 'AEIOUUNaeiouun--')), '[^a-z0-9]+', ' ', 'g'));
$$;

-- Asegurar universidad y facultades base
insert into public.universities (name, code, status)
select 'Universidad Autónoma de Ica', 'UAI', 'active'
where not exists (select 1 from public.universities where public.mnf_norm(code)=public.mnf_norm('UAI'));

with u as (select id from public.universities where public.mnf_norm(code)=public.mnf_norm('UAI') limit 1)
insert into public.faculties (university_id, name, status)
select u.id, 'Facultad de Ciencias de la Salud', 'active' from u
where not exists (select 1 from public.faculties f where f.university_id=u.id and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud'));

with u as (select id from public.universities where public.mnf_norm(code)=public.mnf_norm('UAI') limit 1)
insert into public.faculties (university_id, name, status)
select u.id, 'Facultad de Ingeniería, Ciencias y Administración', 'active' from u
where not exists (select 1 from public.faculties f where f.university_id=u.id and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Administración de Empresas', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Administración de Empresas'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Derecho', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Derecho'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Contabilidad', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Contabilidad'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Arquitectura', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Arquitectura'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Ingeniería Industrial', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Ingeniería Industrial'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Ingeniería Civil', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Ingeniería Civil'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ingeniería, Ciencias y Administración') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Ingeniería de Sistemas', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Ingeniería de Sistemas'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Tecnología Médica en Terapia de Lenguaje', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Tecnología Médica en Terapia de Lenguaje'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Tecnología Médica en Terapia Física y Rehabilitación', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Tecnología Médica en Terapia Física y Rehabilitación'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Tecnología Médica en Laboratorio Clínico y Anatomía Patológica', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Tecnología Médica en Laboratorio Clínico y Anatomía Patológica'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Obstetricia', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Obstetricia'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Psicología', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Psicología'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Enfermería', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Enfermería'));

with ctx as (
  select f.id as faculty_id from public.universities u join public.faculties f on f.university_id=u.id
  where public.mnf_norm(u.code)=public.mnf_norm('UAI') and public.mnf_norm(f.name)=public.mnf_norm('Facultad de Ciencias de la Salud') limit 1
)
insert into public.careers (faculty_id, name, status, created_at, updated_at)
select ctx.faculty_id, 'Medicina Humana', 'active', now(), now() from ctx
where not exists (select 1 from public.careers c where c.faculty_id=ctx.faculty_id and public.mnf_norm(c.name)=public.mnf_norm('Medicina Humana'));

-- Asegurar ciclos I a XIV por order_number
insert into public.cycles (name, order_number)
select 'I ciclo', 1
where not exists (select 1 from public.cycles where order_number=1);
insert into public.cycles (name, order_number)
select 'II ciclo', 2
where not exists (select 1 from public.cycles where order_number=2);
insert into public.cycles (name, order_number)
select 'III ciclo', 3
where not exists (select 1 from public.cycles where order_number=3);
insert into public.cycles (name, order_number)
select 'IV ciclo', 4
where not exists (select 1 from public.cycles where order_number=4);
insert into public.cycles (name, order_number)
select 'V ciclo', 5
where not exists (select 1 from public.cycles where order_number=5);
insert into public.cycles (name, order_number)
select 'VI ciclo', 6
where not exists (select 1 from public.cycles where order_number=6);
insert into public.cycles (name, order_number)
select 'VII ciclo', 7
where not exists (select 1 from public.cycles where order_number=7);
insert into public.cycles (name, order_number)
select 'VIII ciclo', 8
where not exists (select 1 from public.cycles where order_number=8);
insert into public.cycles (name, order_number)
select 'IX ciclo', 9
where not exists (select 1 from public.cycles where order_number=9);
insert into public.cycles (name, order_number)
select 'X ciclo', 10
where not exists (select 1 from public.cycles where order_number=10);
insert into public.cycles (name, order_number)
select 'XI ciclo', 11
where not exists (select 1 from public.cycles where order_number=11);
insert into public.cycles (name, order_number)
select 'XII ciclo', 12
where not exists (select 1 from public.cycles where order_number=12);
insert into public.cycles (name, order_number)
select 'XIII ciclo', 13
where not exists (select 1 from public.cycles where order_number=13);
insert into public.cycles (name, order_number)
select 'XIV ciclo', 14
where not exists (select 1 from public.cycles where order_number=14);

-- Plantilla UAI por unidades
with u as (select id from public.universities where public.mnf_norm(code)=public.mnf_norm('UAI') limit 1)
insert into public.evaluation_templates (university_id, name, description, min_passing_grade, scale_min, scale_max, status, created_at, updated_at)
select u.id, 'UAI - Evaluación por unidades', 'FK1, FK2 y evaluaciones sumativas por unidades', 11, 0, 20, 'active', now(), now() from u
where not exists (select 1 from public.evaluation_templates et where et.university_id=u.id and public.mnf_norm(et.name)=public.mnf_norm('UAI - Evaluación por unidades'));

with template as (select id from public.evaluation_templates where public.mnf_norm(name)=public.mnf_norm('UAI - Evaluación por unidades') limit 1),
data(component_order, short_name, name, unit_name, weight_percent) as (values
  (1, 'FK1-U1', 'FK1 1.ª unidad', 'Unidad 1', 8.33),
  (2, 'FK2-U1', 'FK2 1.ª unidad', 'Unidad 1', 8.33),
  (3, 'U1', 'U1 Evaluación Sumativa', 'Unidad 1', 10.00),
  (4, 'FK1-U2', 'FK1 2.ª unidad', 'Unidad 2', 8.33),
  (5, 'FK2-U2', 'FK2 2.ª unidad', 'Unidad 2', 8.33),
  (6, 'U2', 'U2 Evaluación Sumativa', 'Unidad 2', 15.00),
  (7, 'FK1-U3', 'FK1 3.ª unidad', 'Unidad 3', 8.34),
  (8, 'FK2-U3', 'FK2 3.ª unidad', 'Unidad 3', 8.34),
  (9, 'U3', 'U3 Evaluación Sumativa', 'Unidad 3', 25.00)
)
insert into public.evaluation_components (template_id, component_order, short_name, name, unit_name, weight_percent, status, created_at, updated_at)
select t.id, d.component_order, d.short_name, d.name, d.unit_name, d.weight_percent, 'active', now(), now()
from data d cross join template t
where not exists (select 1 from public.evaluation_components ec where ec.template_id=t.id and ec.component_order=d.component_order);

create temporary table tmp_uai_official_courses (
  faculty_name text not null,
  career_name text not null,
  cycle_number int not null,
  course_name text not null,
  unique (faculty_name, career_name, cycle_number, course_name)
);

insert into tmp_uai_official_courses (faculty_name, career_name, cycle_number, course_name) values
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',1,'Redacción y Comunicación'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',1,'Matemáticas'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',1,'Métodos de Estudio Universitario'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',1,'Filosofía y Ética'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',1,'Cultura Ambiental'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',1,'Introducción a la Administración'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',2,'Redacción Académica'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',2,'Matemática Financiera'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',2,'Metodología de la Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',2,'Realidad Nacional y Globalización'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',2,'Cultura Inclusiva'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',2,'Economía'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',3,'TICs para la gestión'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',3,'Contabilidad General'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',3,'Fundamentos de Gestión del Talento'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',3,'Fundamentos de Marketing'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',3,'Estadística'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',3,'Actividades de Proyección Social I'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',4,'Contabilidad Financiera'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',4,'Derecho Empresarial y Laboral'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',4,'Responsabilidad Social de la Empresa'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',4,'Investigación de Mercados'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',4,'Métodos Cuantitativos'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',4,'Actividades de Proyección Social II'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',5,'Reglamentación y Tributación Empresarial'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',5,'Selección y Evaluación del Desempeño'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',5,'Dirección y Planificación Estratégica'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',5,'Comportamiento del Consumidor'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',5,'Gestión de Operaciones'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',5,'Actividades de Proyección Social III'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',6,'Capacitación y Desarrollo de Competencias'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',6,'Logística Empresarial'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',6,'Marketing Estratégico'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',6,'Gestión Pública'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',6,'Diseño Organizacional y Procesos'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',6,'Finanzas Empresariales'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',7,'Compensaciones y Remuneraciones'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',7,'Desing Thinking'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',7,'Marketing Digital'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',7,'Inglés I'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',7,'Análisis Financiero para la Toma de Decisiones'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',7,'Taller de Investigación I'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',8,'Liderazgo y Gestión de Equipos'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',8,'Innovación y Emprendimiento'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',8,'Marketing de Servicios'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',8,'Inglés II'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',8,'Taller de Investigación II'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',8,'Gestión Estratégica del Financiamiento'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Atracción y Retención del talento humano'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Branding y Gestión de Marca'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Gestión de Riesgos Financieros'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Gestión de la Calidad'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Coaching y Mentoring profesional'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Análisis de Datos y Métricas en Marketing'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Finanzas internacionales'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Negociación y resolución de conflictos'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Electivo 1'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Seminario de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',9,'Formulación y Evaluación de Proyectos de Inversión'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Dirección de personas'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Dirección Financiera'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Dirección Comercial y de Marketing'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Electivo 2'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Trabajo de investigación Específico Obligatoria'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Indicadores de Control de Gestión del Capital Humano'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Gestión Estratégica por Resultados'),
('Facultad de Ingeniería, Ciencias y Administración','Administración de Empresas',10,'Diseño del Plan de Marketing'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',1,'Redacción y Comunicación'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',1,'Matemática I'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',1,'Métodos de Estudio Universitario'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',1,'Filosofía y Ética'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',1,'Introducción al Derecho'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',1,'Cultura Ambiental'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',2,'Metodología de la Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',2,'Matemática II'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',2,'Realidad Nacional y Globalización'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',2,'Administración y Emprendimiento'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',2,'Expresión oral y Liderazgo'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',2,'Cultura Inclusiva'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',3,'Derecho Civil - Título Preliminar Persona Natural'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',3,'Derecho Constitucional'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',3,'Ciencia Política'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',3,'Filosofía del Derecho'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',3,'Teoría General del Proceso'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',3,'Criminología'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',3,'Actividades de Proyección Social I'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',4,'Derecho Civil - Título Preliminar Persona Jurídica'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',4,'Medios Alternativos de Resolución de Conflictos'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',4,'Derecho de Familia Niño y Adolescente'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',4,'Razonamiento del Derecho'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',4,'Derecho Penal – Parte General'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',4,'Derecho Administrativo'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',4,'Actividades de Proyección Social II'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',5,'Acto Jurídico'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',5,'Derecho Procesal Civil I'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',5,'Derecho Procesal Constitucional'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',5,'Derecho de Sucesiones'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',5,'Derechos Reales'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',5,'Derecho Penal – Parte Especial'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',5,'Actividades de Proyección Social III'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Derecho Comercial'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Derecho de Obligaciones'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Derecho del Trabajo'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Contratos'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Derecho Ambiental y Responsabilidad Social'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Derecho Penal Económico'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Derecho Tributario'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',6,'Derecho Empresarial'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',7,'Derecho Registral y Notarial'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',7,'Derecho Procesal Penal'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',7,'Inglés I'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',7,'Derecho Procesal Laboral'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',7,'Arbitraje'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',7,'Taller de Investigación I'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',8,'Inglés II'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',8,'Derecho Internacional Público'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',8,'Derecho Procesal Tributario'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',8,'Tributos del Derecho Municipal y Regional'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',8,'Taller de Investigación II'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',8,'Electivo 1'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',9,'Gestión Pública'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',9,'Auditoría y Fiscalización Tributaria'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',9,'Derecho Internacional Privado'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',9,'Electivo 2'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',9,'Proyecto de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',9,'Derecho de la Propiedad Intelectual y Derecho del Consumidor'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',9,'Teoría del Delito'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',10,'Derecho Penal Militar Policial'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',10,'Trabajo de Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',10,'Seminario de Gestión Pública'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',10,'Seminario de Derecho Penal'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',10,'Electivo 3'),
('Facultad de Ingeniería, Ciencias y Administración','Derecho',10,'Seminario de Derecho Civil'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',1,'Redacción y Comunicación'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',1,'Matemática I'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',1,'Métodos de estudio Universitario'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',1,'Filosofía y Ética'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',1,'Contabilidad General'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',1,'Cultura Ambiental'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',2,'Metodología de la Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',2,'Matemática II'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',2,'Realidad Nacional y Globalización'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',2,'Cultura Inclusiva'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',2,'Economía'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',2,'Contabilidad Financiera'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',3,'Estadística'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',3,'Derecho Empresarial'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',3,'Actividades de Proyección Social'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',3,'Administración General'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',3,'Contabilidad de Sociedades'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',4,'Matemática Financiera'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',4,'Legislación Laboral'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',4,'Informática Contable'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',4,'Microeconomía'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',4,'Marketing'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',5,'Finanzas'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',5,'Legislación Tributaria'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',5,'Gestión del Talento Humano'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',5,'Macroeconomía'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',5,'Contabilidad Costos I'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',6,'Estudio Contable de los Tributos'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',6,'Aplicaciones contables bajo NIIF'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',6,'Formulación y Evaluación de Estados Financieros'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',6,'Contabilidad Costos II'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',6,'Finanzas Corporativas'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',7,'Auditoría Financiera'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',7,'Taller Investigación I'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',7,'Presupuesto Público y Privado'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',7,'Inglés I'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',7,'Finanzas Internacionales'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',8,'Taller de Investigación II'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',8,'Auditoría Tributaria'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',8,'Inglés II'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',8,'Procedimientos Tributarios'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',8,'Desarrollo de Habilidades Gerenciales'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',9,'Gerencia Estratégica'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',9,'Contabilidad Gubernamental'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',9,'Formulación y Evaluación de proyectos de Inversión'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',9,'Electivo 1'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',9,'Proyecto de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',10,'Peritaje Contable'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',10,'Trabajo de Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',10,'Contabilidad Gerencial'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',10,'Prácticas pre Profesionales'),
('Facultad de Ingeniería, Ciencias y Administración','Contabilidad',10,'Electivo 2'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',1,'Métodos de Estudio Universitario'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',1,'Redacción y Comunicación'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',1,'Filosofía y Ética'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',1,'Matemáticas Aplicadas'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',1,'Geometría Descriptiva'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',1,'Introducción a la Arquitectura'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',2,'Realidad Nacional y Globalización'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',2,'Metodología de la Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',2,'Administración y Emprendimiento'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',2,'Cálculo I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',2,'Física I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',2,'Dibujo Arquitectónico I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',3,'Cultura Inclusiva'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',3,'Cultura Ambiental'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',3,'Informática para la Toma de Decisiones'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',3,'Física II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',3,'Historia de la Arquitectura I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',3,'Dibujo Arquitectónico II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',4,'Actividades de Proyección Social I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',4,'Construcción'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',4,'Estructuras I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',4,'Historia de la Arquitectura II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',4,'Taller de Diseño I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',4,'Arquitectura Sostenible I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',5,'Actividades de Proyección Social II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',5,'Urbanismo I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',5,'Estructuras II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',5,'Historia de la Arquitectura III'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',5,'Taller de Diseño II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',5,'Arquitectura Sostenible II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',6,'Urbanismo II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',6,'Estructuras III'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',6,'Historia de la Arquitectura IV'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',6,'Taller de Diseño III'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',6,'Representación Digital I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',6,'Instalaciones en edificaciones'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',7,'Planificación Urbana I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',7,'Taller de Diseño IV'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',7,'Representación Digital II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',7,'Gestión de Proyectos'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',7,'Inglés I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',7,'Taller de Investigación I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',8,'Planificación Urbana II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',8,'Taller de Diseño V'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',8,'Paisajismo urbano'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',8,'Electivo I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',8,'Taller de Investigación II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',9,'Proyecto de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',9,'Taller de Proyecto Final I'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',9,'Taller de Diseño VI'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',9,'Electivo II'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',10,'Trabajo de Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',10,'Electivo III'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',10,'Taller de Diseño VII'),
('Facultad de Ingeniería, Ciencias y Administración','Arquitectura',10,'Taller de Proyecto Final II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',1,'Redacción y Comunicación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',1,'Matemáticas'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',1,'Métodos de estudio universitario'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',1,'Introducción a las Ingenierías'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',1,'Filosofía y Ética'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',1,'Cultura Ambiental'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',2,'Metodología de la Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',2,'Cálculo I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',2,'Realidad nacional y Globalización'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',2,'Administración General'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',2,'Dibujo de Ingeniería'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',2,'Cultura inclusiva'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',3,'Cálculo II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',3,'Física I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',3,'Teoría general de sistemas'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',3,'Estadística y Probabilidades'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',3,'Informática para la toma de decisiones'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',3,'Actividades de Proyección Social'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',4,'Algoritmo y Estructura de Datos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',4,'Física II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',4,'Estadística aplicada'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',4,'Economía general'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',4,'Química general'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',4,'Actividades de Proyección Social II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',5,'Base de datos y programación visual'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',5,'Logística Empresarial'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',5,'Química orgánica e industrial'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',5,'Microeconomía'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',5,'Ingeniería eléctrica y eléctrónica'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',5,'Actividades de Proyección Social III'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',6,'Resistencia de Materiales'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',6,'Gestión del Talento Humano'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',6,'Contabilidad General'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',6,'Automatización industrial'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',6,'Ingeniería de Métodos I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',7,'Investigación de Operaciones I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',7,'Taller Investigación I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',7,'Supply Chain Management'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',7,'Costos y Presupuestos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',7,'Ingeniería de Métodos II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',7,'Inglés I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',8,'Investigación de Operaciones II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',8,'Taller Investigación II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',8,'Gestión de la Calidad'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',8,'Logística inversa'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',8,'Inglés II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',8,'Marketing Estratégico'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',9,'Innovación y Emprendimiento de Negocio'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',9,'Planeamiento y Control de la Producción I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',9,'Formulación y Evaluación de Proyectos Industriales'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',9,'Electivo 1'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',9,'Proyecto de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',10,'Seguridad y Salud Ocupacional'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',10,'Desarrollo de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',10,'Planeamiento y Control de la Producción II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',10,'Derecho Empresarial y Legislación laboral'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Industrial',10,'Electivo 2'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',1,'Redacción y Comunicación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',1,'Matemática para Ingenieros'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',1,'Métodos de Estudio Universitario');

insert into tmp_uai_official_courses (faculty_name, career_name, cycle_number, course_name) values
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',1,'Introducción a las Ingenierías'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',1,'Filosofía y Ética'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',1,'Dibujo de Ingeniería I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',2,'Metodología de la Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',2,'Cálculo I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',2,'Realidad Nacional y Globalización'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',2,'Administración y Emprendimiento'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',2,'Dibujo de ingeniería II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',2,'Física'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',3,'Cultura Inclusiva'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',3,'Cultura Ambiental'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',3,'Química'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',3,'Estática'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',3,'Cálculo II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',3,'Topografía'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',3,'Actividades de proyección social I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',4,'Geología'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',4,'Materiales de Construcción'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',4,'Estadística y Probabilidades'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',4,'Dinámica'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',4,'Informática para la Toma de Decisiones'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',4,'Actividades de Proyección Social II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',4,'Cálculo III'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',5,'Mecánica de Suelos I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',5,'Mecánica de Fluidos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',5,'Tecnología de los Materiales'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',5,'Tecnología del Concreto'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',5,'Diseño Arquitectónico'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',5,'Actividades de proyección social III'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',6,'Hidráulica'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',6,'Construcción I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',6,'Investigación de Operaciones I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',6,'Resistencia de Materiales'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',6,'Costos y Programación de obras'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',6,'Mecánica de Suelos II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',7,'Hidrología'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',7,'Construcción II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',7,'Análisis Estructural I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',7,'Investigación de Operaciones II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',7,'Inglés I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',7,'Taller de Investigación I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',8,'Abastecimiento de Agua y Alcantarillado'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',8,'Recursos Hidráulicos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',8,'Análisis Estructural II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',8,'Taller de Investigación II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',8,'Caminos y Puentes'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',8,'Inglés II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',9,'Concreto Armado'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',9,'Pavimentos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',9,'Proyecto de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',9,'Electivo'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',9,'Instalaciones Eléctricas y Sanitarias'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',10,'Residencia y Supervisión de Obras'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',10,'Tecnología de la Construcción Antisísmica'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',10,'Gestión de Proyectos de Construcción'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',10,'Trabajo de Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería Civil',10,'Electivo'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',1,'Matemáticas para Ingenieros'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',1,'Redacción y Comunicación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',1,'Métodos de Estudio Universitario'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',1,'Introducción a las Ingenierías'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',1,'Filosofía y Ética'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',1,'Dibujo de Ingeniería'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',2,'Cálculo I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',2,'Metodología de Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',2,'Física I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',2,'Realidad Nacional y Globalización'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',2,'Administración y Emprendimiento'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',2,'Cultura Inclusiva'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',3,'Cultura Ambiental'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',3,'Cálculo II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',3,'Física II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',3,'Teoría General de Sistemas'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',3,'Algoritmos y Estructura de Datos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',3,'Actividades de Proyección Social I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',4,'Estadística y Probabilidades'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',4,'Informática para la Toma de Decisiones'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',4,'Química'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',4,'Modelamiento de Datos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',4,'Taller de Programación I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',4,'Actividades de Proyección Social II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',5,'Estadística Aplicada'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',5,'Investigación de Operaciones I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',5,'Ingeniería de Software'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',5,'Base de Datos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',5,'Taller de Programación II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',5,'Actividades de Proyección Social III'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',6,'Dirección de Empresas'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',6,'Arquitectura del Computador'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',6,'Circuitos Analógicos y Digitales'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',6,'Taller de Programación III'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',6,'Investigación de Operaciones II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',7,'Gestión del Capital Humano'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',7,'Contabilidad General'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',7,'Operaciones Unitarias'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',7,'Taller de Programación IV'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',7,'Taller de Investigación I'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',8,'Costos y Presupuestos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',8,'Legislación Empresarial'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',8,'Automatización y control de Procesos Industriales'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',8,'Redes y Comunicación de Datos'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',8,'Inglés II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',8,'Taller de Investigación II'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',9,'Planeamiento Estratégico'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',9,'Marketing Estratégico'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',9,'Gestión de Proyectos TI'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',9,'Inteligencia de Negocios'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',9,'Electivo 1'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',9,'Seminario de Tesis'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',10,'Seguridad de Sistemas'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',10,'Seminario de Investigación'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',10,'Calidad de Software y Auditoría de Sistemas'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',10,'Formulación y Evaluación de Proyectos TI'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',10,'Electivo 2'),
('Facultad de Ingeniería, Ciencias y Administración','Ingeniería de Sistemas',10,'Electivo 3'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',1,'Cultura Ambiental'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',1,'Redacción y Comunicación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',1,'Matemática I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',1,'Filosofía y Ética'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',1,'Métodos de Estudio Universitario'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',1,'Introducción a la Tecnología Médica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',1,'Biología General'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',2,'Realidad Nacional y Globalización'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',2,'Administración y Emprendimiento'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',2,'Metodología de la Investigación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',2,'Cultura Inclusiva'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',2,'Anatomía Humana'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',3,'Estadística'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',3,'Fisiología Humana'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',3,'Histología y Embriología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',3,'Introducción a la Fonoaudiología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',3,'Actividades de Proyección Social I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',3,'Neuroanatomía Funcional de cabeza y cuello'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',4,'Antropología de la Salud'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',4,'Anatomía y fisiología del sistema estomatognático I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',4,'Anatomía y fisiología del sistema auditivo'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',4,'Neurolingüistica y Neuropsicología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',4,'Fundamentos lingüísticos para Fonoaudiología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',4,'Actividades de Proyección Social II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',5,'Anatomía y fisiología del sistema estomatognático II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',5,'Semántica y Pragmática'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',5,'Fonética y fonología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',5,'Morfosintaxis del Español'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',5,'Epidemiología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',5,'Actividades de Proyección Social III'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',6,'Evaluación de la Comunicación, el lenguaje y el habla'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',6,'Evaluación de la voz'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',6,'Evaluación de la audición'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',6,'Electivo 1'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',6,'Salud Pública'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',6,'Evaluación de la motricidad oracional'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',7,'Patologías de la comunicación, el lenguaje y el habla e intervención'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',7,'Patologías de la audición e intervención'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',7,'Gestión y Administración en Servicios de Salud'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',7,'Patologías de la voz e intervención'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',7,'Electivo 2'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',7,'Taller Investigación I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',7,'Inglés I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',8,'Taller de investigación II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',8,'Electivo 3'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',8,'Inglés II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',8,'Rehabilitación Basada en la Comunidad'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',8,'Investigación Fonoaudiológica Aplicada'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',9,'Seminario de Tesis'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',9,'Internado I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',10,'Trabajo de Investigación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia de Lenguaje',10,'Internado II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',1,'Cultura Ambiental'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',1,'Redacción y Comunicación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',1,'Matemática I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',1,'Filosofía y Ética'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',1,'Métodos de Estudio Universitario'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',1,'Introducción a la Tecnología Médica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',1,'Biología General'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',2,'Realidad Nacional y Globalización'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',2,'Administración y Emprendimiento'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',2,'Metodología de la Investigación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',2,'Cultura Inclusiva'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',2,'Anatomía Humana'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',3,'Estadística'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',3,'Fisiología Humana'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',3,'Histología y Embriología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',3,'Organización y Función corporal I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',3,'Actividades de Proyección Social I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',3,'Fisiología del ejercicio'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',4,'Antropología de la Salud'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',4,'Organización y Función Corporal II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',4,'Biomecánica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',4,'Psicomotricidad'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',4,'Evaluación y Diagnóstico Fisioterapéutico'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',4,'Actividades de Proyección Social II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',5,'Fisioterapia Musculoesquelética'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',5,'Ergonomía y Salud Ocupacional'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',5,'Fisiopatología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',5,'Nutrición'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',5,'Epidemiología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',5,'Actividades de Proyección Social III'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',6,'Fisioterapia Pediátrica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',6,'Farmacología Terapéutica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',6,'Fisioterapia Neurológica I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',6,'Electivo 1'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',6,'Salud Pública'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',7,'Fisioterapia Cardiorrespiratoria'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',7,'Fisioterapia Neurológica II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',7,'Gestión y Administración en Servicios de Salud'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',7,'Fisioterapia Geriátrica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',7,'Electivo 2'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',7,'Taller Investigación I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',7,'Inglés I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',8,'Taller de investigación II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',8,'Electivo 3'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',8,'Inglés II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',8,'Rehabilitación Basada en la Comunidad'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',8,'Actividad Física, Deporte Adaptado y Paradeporte'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',8,'Salud Mental y Rehabilitación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',9,'Seminario de Tesis'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',9,'Internado I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',10,'Trabajo de Investigación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Terapia Física y Rehabilitación',10,'Internado II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',1,'Cultura Ambiental'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',1,'Redacción y Comunicación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',1,'Matemática I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',1,'Filosofía y Ética'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',1,'Métodos de Estudio Universitario'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',1,'Introducción a la Tecnología Médica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',1,'Biología General'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',2,'Realidad Nacional y Globalización'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',2,'Administración y Emprendimiento'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',2,'Metodología de la Investigación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',2,'Cultura Inclusiva'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',2,'Anatomía Humana'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',3,'Estadística'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',3,'Fisiología Humana'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',3,'Histología y Embriología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',3,'Química Orgánica e Inorgánica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',3,'Actividades de Proyección Social I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',3,'Física Aplicada'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',4,'Antropología de la Salud'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',4,'Bioquímica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',4,'Genética y Citogenética'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',4,'Hematología I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',4,'Patología General'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',4,'Actividades de Proyección Social II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',5,'Microbiología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',5,'Parasitología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',5,'Hematología II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',5,'Bioquímica Clínica'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',5,'Epidemiología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',5,'Actividades de Proyección Social III'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Inmunología Especial'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Hemoterapia y Banco de Sangre'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Histotecnología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Citotecnología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Farmacología y Toxicología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Uroanálisis y Fluidos Corporales'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Electivo 1'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',6,'Salud Pública'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',7,'Inmunología'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',7,'Biología Molecular'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',7,'Gestión y Administración en Servicios de Salud'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',7,'Laboratorio Forense'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',7,'Electivo 2'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',7,'Taller Investigación I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',7,'Inglés I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',8,'Taller de investigación II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',8,'Electivo 3'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',8,'Inglés II'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',9,'Seminario de Tesis'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',9,'Internado I'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',10,'Trabajo de Investigación'),
('Facultad de Ciencias de la Salud','Tecnología Médica en Laboratorio Clínico y Anatomía Patológica',10,'Internado II'),
('Facultad de Ciencias de la Salud','Obstetricia',1,'Redacción y Comunicación'),
('Facultad de Ciencias de la Salud','Obstetricia',1,'Matemática I'),
('Facultad de Ciencias de la Salud','Obstetricia',1,'Métodos de estudio universitario'),
('Facultad de Ciencias de la Salud','Obstetricia',1,'Filosofía y Ética'),
('Facultad de Ciencias de la Salud','Obstetricia',1,'Introducción a la obstetricia'),
('Facultad de Ciencias de la Salud','Obstetricia',1,'Cultura Ambiental'),
('Facultad de Ciencias de la Salud','Obstetricia',2,'Metodología de la Investigación'),
('Facultad de Ciencias de la Salud','Obstetricia',2,'Matemática II'),
('Facultad de Ciencias de la Salud','Obstetricia',2,'Realidad nacional y Globalización'),
('Facultad de Ciencias de la Salud','Obstetricia',2,'Administración General'),
('Facultad de Ciencias de la Salud','Obstetricia',2,'Anatomía y Fisiología'),
('Facultad de Ciencias de la Salud','Obstetricia',2,'Cultura inclusiva'),
('Facultad de Ciencias de la Salud','Obstetricia',3,'Enfermería obstetrica'),
('Facultad de Ciencias de la Salud','Obstetricia',3,'Bioestadística y epidemiología'),
('Facultad de Ciencias de la Salud','Obstetricia',3,'Biología'),
('Facultad de Ciencias de la Salud','Obstetricia',3,'Histología'),
('Facultad de Ciencias de la Salud','Obstetricia',3,'Antropología de la Salud'),
('Facultad de Ciencias de la Salud','Obstetricia',3,'Actividades de Proyección Social I'),
('Facultad de Ciencias de la Salud','Obstetricia',4,'Semiología'),
('Facultad de Ciencias de la Salud','Obstetricia',4,'Química y Bioquímica'),
('Facultad de Ciencias de la Salud','Obstetricia',4,'Microbiología y Parasitología'),
('Facultad de Ciencias de la Salud','Obstetricia',4,'Embriología y Genética'),
('Facultad de Ciencias de la Salud','Obstetricia',4,'Salud de la Mujer'),
('Facultad de Ciencias de la Salud','Obstetricia',4,'Actividades de Proyección Social II'),
('Facultad de Ciencias de la Salud','Obstetricia',5,'Farmacología y Terapéutica Obstétrica'),
('Facultad de Ciencias de la Salud','Obstetricia',5,'Sexualidad Humana y Reproducción'),
('Facultad de Ciencias de la Salud','Obstetricia',5,'Tecnología de información en salud'),
('Facultad de Ciencias de la Salud','Obstetricia',5,'Administración y Gerencia en Salud'),
('Facultad de Ciencias de la Salud','Obstetricia',5,'Obstetricia I');

insert into tmp_uai_official_courses (faculty_name, career_name, cycle_number, course_name) values
('Facultad de Ciencias de la Salud','Obstetricia',5,'Actividades de Proyección Social III'),
('Facultad de Ciencias de la Salud','Obstetricia',6,'Psicoprofilaxis Obstétrica y estimulación prenatal'),
('Facultad de Ciencias de la Salud','Obstetricia',6,'Laboratorio clínico - Diagnóstico por imágenes'),
('Facultad de Ciencias de la Salud','Obstetricia',6,'Gestión administrativa pública y privada'),
('Facultad de Ciencias de la Salud','Obstetricia',6,'Obstetricia II'),
('Facultad de Ciencias de la Salud','Obstetricia',6,'Estadística aplicada a la investigación'),
('Facultad de Ciencias de la Salud','Obstetricia',6,'Obstetricia Comunitaria'),
('Facultad de Ciencias de la Salud','Obstetricia',7,'Obstetricia III'),
('Facultad de Ciencias de la Salud','Obstetricia',7,'Proyecto de Tesis'),
('Facultad de Ciencias de la Salud','Obstetricia',7,'Inglés I'),
('Facultad de Ciencias de la Salud','Obstetricia',7,'Electivo 1'),
('Facultad de Ciencias de la Salud','Obstetricia',7,'Cirugía Instrumental y Anestesiología'),
('Facultad de Ciencias de la Salud','Obstetricia',7,'Monitoreo fetal y electrónico'),
('Facultad de Ciencias de la Salud','Obstetricia',8,'Medicina Legal y Forense'),
('Facultad de Ciencias de la Salud','Obstetricia',8,'Internado I'),
('Facultad de Ciencias de la Salud','Obstetricia',8,'Inglés II'),
('Facultad de Ciencias de la Salud','Obstetricia',8,'Electivo 2'),
('Facultad de Ciencias de la Salud','Obstetricia',8,'Desarrollo de Tesis'),
('Facultad de Ciencias de la Salud','Obstetricia',9,'Internado II'),
('Facultad de Ciencias de la Salud','Obstetricia',10,'Internado III'),
('Facultad de Ciencias de la Salud','Psicología',1,'Redacción y Comunicación'),
('Facultad de Ciencias de la Salud','Psicología',1,'Matemática I'),
('Facultad de Ciencias de la Salud','Psicología',1,'Filosofía y Ética'),
('Facultad de Ciencias de la Salud','Psicología',1,'Métodos de Estudios Universitario'),
('Facultad de Ciencias de la Salud','Psicología',1,'Introducción a la Psicología'),
('Facultad de Ciencias de la Salud','Psicología',1,'Biología'),
('Facultad de Ciencias de la Salud','Psicología',2,'Metodología de la Investigación'),
('Facultad de Ciencias de la Salud','Psicología',2,'Matemática II'),
('Facultad de Ciencias de la Salud','Psicología',2,'Realidad nacional y Globalización'),
('Facultad de Ciencias de la Salud','Psicología',2,'Administración y emprendimiento'),
('Facultad de Ciencias de la Salud','Psicología',2,'Anatomía y Fisiología'),
('Facultad de Ciencias de la Salud','Psicología',2,'Cultura inclusiva'),
('Facultad de Ciencias de la Salud','Psicología',3,'Estadística'),
('Facultad de Ciencias de la Salud','Psicología',3,'Cultura Ambiental'),
('Facultad de Ciencias de la Salud','Psicología',3,'Psicofisiología'),
('Facultad de Ciencias de la Salud','Psicología',3,'Antropología de la Salud'),
('Facultad de Ciencias de la Salud','Psicología',3,'Sistemas psicológicos'),
('Facultad de Ciencias de la Salud','Psicología',3,'Actividades de Proyección Social I'),
('Facultad de Ciencias de la Salud','Psicología',4,'Procesos Cognitivos'),
('Facultad de Ciencias de la Salud','Psicología',4,'Psicometría'),
('Facultad de Ciencias de la Salud','Psicología',4,'Psicología del Aprendizaje'),
('Facultad de Ciencias de la Salud','Psicología',4,'Neuropsicología'),
('Facultad de Ciencias de la Salud','Psicología',4,'Desarrollo Psicológico I'),
('Facultad de Ciencias de la Salud','Psicología',4,'Actividades de Proyección Social II'),
('Facultad de Ciencias de la Salud','Psicología',5,'Pruebas Psicológicas'),
('Facultad de Ciencias de la Salud','Psicología',5,'Psicología de la Personalidad'),
('Facultad de Ciencias de la Salud','Psicología',5,'Entrevista y Observación'),
('Facultad de Ciencias de la Salud','Psicología',5,'Psicopatología I'),
('Facultad de Ciencias de la Salud','Psicología',5,'Desarrollo Psicológico II'),
('Facultad de Ciencias de la Salud','Psicología',5,'Actividades de Proyección Social III'),
('Facultad de Ciencias de la Salud','Psicología',6,'Psicología Comunitaria'),
('Facultad de Ciencias de la Salud','Psicología',6,'Psicología Educativa'),
('Facultad de Ciencias de la Salud','Psicología',6,'Psicopatología II'),
('Facultad de Ciencias de la Salud','Psicología',6,'Psicología Organizacional'),
('Facultad de Ciencias de la Salud','Psicología',6,'Evaluación y Diagnóstico'),
('Facultad de Ciencias de la Salud','Psicología',6,'Psicología Clínica y de la Salud'),
('Facultad de Ciencias de la Salud','Psicología',7,'Psicología de la Educación Especial'),
('Facultad de Ciencias de la Salud','Psicología',7,'Psicología de la sexualidad'),
('Facultad de Ciencias de la Salud','Psicología',7,'Psicología de los Recursos Humanos'),
('Facultad de Ciencias de la Salud','Psicología',7,'Inglés I'),
('Facultad de Ciencias de la Salud','Psicología',7,'Informes Psicológicos'),
('Facultad de Ciencias de la Salud','Psicología',7,'Taller de Investigación I'),
('Facultad de Ciencias de la Salud','Psicología',8,'Taller de investigación II'),
('Facultad de Ciencias de la Salud','Psicología',8,'Orientación y Consejo Psicológico'),
('Facultad de Ciencias de la Salud','Psicología',8,'Capacitación y Desarrollo del Talento'),
('Facultad de Ciencias de la Salud','Psicología',8,'Inglés II'),
('Facultad de Ciencias de la Salud','Psicología',8,'Técnicas psicoterapéuticas'),
('Facultad de Ciencias de la Salud','Psicología',8,'Psicología Forense'),
('Facultad de Ciencias de la Salud','Psicología',9,'Seminario de Tesis I'),
('Facultad de Ciencias de la Salud','Psicología',9,'Internado I'),
('Facultad de Ciencias de la Salud','Psicología',9,'Electivo 1'),
('Facultad de Ciencias de la Salud','Psicología',10,'Seminario de Tesis II'),
('Facultad de Ciencias de la Salud','Psicología',10,'Internado II'),
('Facultad de Ciencias de la Salud','Psicología',10,'Electivo 2'),
('Facultad de Ciencias de la Salud','Enfermería',1,'Redacción y Comunicación'),
('Facultad de Ciencias de la Salud','Enfermería',1,'Matemática I'),
('Facultad de Ciencias de la Salud','Enfermería',1,'Filosofía y Ética'),
('Facultad de Ciencias de la Salud','Enfermería',1,'Métodos de Estudio Universitario'),
('Facultad de Ciencias de la Salud','Enfermería',1,'Introducción a la Enfermería'),
('Facultad de Ciencias de la Salud','Enfermería',1,'Biología'),
('Facultad de Ciencias de la Salud','Enfermería',2,'Matemática II'),
('Facultad de Ciencias de la Salud','Enfermería',2,'Realidad Nacional y Globalización'),
('Facultad de Ciencias de la Salud','Enfermería',2,'Administración y Emprendimiento'),
('Facultad de Ciencias de la Salud','Enfermería',2,'Metodología de la Investigación'),
('Facultad de Ciencias de la Salud','Enfermería',2,'Cultura Inclusiva'),
('Facultad de Ciencias de la Salud','Enfermería',2,'Anatomía y Fisiología'),
('Facultad de Ciencias de la Salud','Enfermería',3,'Estadística'),
('Facultad de Ciencias de la Salud','Enfermería',3,'Cultura Ambiental'),
('Facultad de Ciencias de la Salud','Enfermería',3,'Química y Bioquímica'),
('Facultad de Ciencias de la Salud','Enfermería',3,'Antropología de la Salud'),
('Facultad de Ciencias de la Salud','Enfermería',3,'Actividades de Proyección Social I'),
('Facultad de Ciencias de la Salud','Enfermería',3,'Método de Atención de Enfermería'),
('Facultad de Ciencias de la Salud','Enfermería',4,'Semiología'),
('Facultad de Ciencias de la Salud','Enfermería',4,'Enfermería Clínica'),
('Facultad de Ciencias de la Salud','Enfermería',4,'Microbiología y Parasitología'),
('Facultad de Ciencias de la Salud','Enfermería',4,'Farmacología y Terapéutica'),
('Facultad de Ciencias de la Salud','Enfermería',4,'Enfermería Pediátrica'),
('Facultad de Ciencias de la Salud','Enfermería',4,'Actividades de Proyección Social II'),
('Facultad de Ciencias de la Salud','Enfermería',5,'Educación para la salud'),
('Facultad de Ciencias de la Salud','Enfermería',5,'Nutrición y Dietoterapia'),
('Facultad de Ciencias de la Salud','Enfermería',5,'Tecnología de Información en Salud'),
('Facultad de Ciencias de la Salud','Enfermería',5,'Enfermería en Salud del Adulto I'),
('Facultad de Ciencias de la Salud','Enfermería',5,'Enfermería en Atención Primaria de la Salud'),
('Facultad de Ciencias de la Salud','Enfermería',5,'Actividades de Proyección Social III'),
('Facultad de Ciencias de la Salud','Enfermería',6,'Taller de formación clínica'),
('Facultad de Ciencias de la Salud','Enfermería',6,'Enfermería en Salud Comunitaria I'),
('Facultad de Ciencias de la Salud','Enfermería',6,'Enfermería geriátrica'),
('Facultad de Ciencias de la Salud','Enfermería',6,'Enfermería en Medicina Alternativa'),
('Facultad de Ciencias de la Salud','Enfermería',6,'Enfermería en Salud del Adulto II'),
('Facultad de Ciencias de la Salud','Enfermería',6,'Electivo 1'),
('Facultad de Ciencias de la Salud','Enfermería',6,'Enfermería en Salud Mental y Psiquiatría'),
('Facultad de Ciencias de la Salud','Enfermería',7,'Enfermería en Salud Comunitaria II'),
('Facultad de Ciencias de la Salud','Enfermería',7,'Enfermería en Salud de la Mujer'),
('Facultad de Ciencias de la Salud','Enfermería',7,'Enfermería en Emergencias y Desastres'),
('Facultad de Ciencias de la Salud','Enfermería',7,'Salud Pública'),
('Facultad de Ciencias de la Salud','Enfermería',7,'Electivo 2'),
('Facultad de Ciencias de la Salud','Enfermería',7,'Taller Investigación I'),
('Facultad de Ciencias de la Salud','Enfermería',7,'Inglés I'),
('Facultad de Ciencias de la Salud','Enfermería',8,'Taller de investigación II'),
('Facultad de Ciencias de la Salud','Enfermería',8,'Electivo 3'),
('Facultad de Ciencias de la Salud','Enfermería',8,'Inglés II'),
('Facultad de Ciencias de la Salud','Enfermería',9,'Seminario de Tesis'),
('Facultad de Ciencias de la Salud','Enfermería',9,'Internado I'),
('Facultad de Ciencias de la Salud','Enfermería',10,'Trabajo de Investigación'),
('Facultad de Ciencias de la Salud','Enfermería',10,'Internado II'),
('Facultad de Ciencias de la Salud','Medicina Humana',1,'Matemática I'),
('Facultad de Ciencias de la Salud','Medicina Humana',1,'Redacción y Comunicación'),
('Facultad de Ciencias de la Salud','Medicina Humana',1,'Métodos de estudio universitario'),
('Facultad de Ciencias de la Salud','Medicina Humana',1,'Filosofía y Ética'),
('Facultad de Ciencias de la Salud','Medicina Humana',1,'Introducción a la Medicina'),
('Facultad de Ciencias de la Salud','Medicina Humana',1,'Biología'),
('Facultad de Ciencias de la Salud','Medicina Humana',2,'Matemática II'),
('Facultad de Ciencias de la Salud','Medicina Humana',2,'Metodología de la Investigación'),
('Facultad de Ciencias de la Salud','Medicina Humana',2,'Realidad nacional y Globalización'),
('Facultad de Ciencias de la Salud','Medicina Humana',2,'Administración y emprendimiento'),
('Facultad de Ciencias de la Salud','Medicina Humana',2,'Cultura inclusiva'),
('Facultad de Ciencias de la Salud','Medicina Humana',2,'Cultura ambiental'),
('Facultad de Ciencias de la Salud','Medicina Humana',2,'Anatomía'),
('Facultad de Ciencias de la Salud','Medicina Humana',3,'Biología Celular'),
('Facultad de Ciencias de la Salud','Medicina Humana',3,'Biofísica'),
('Facultad de Ciencias de la Salud','Medicina Humana',3,'Química orgánica'),
('Facultad de Ciencias de la Salud','Medicina Humana',3,'Embriología y genética'),
('Facultad de Ciencias de la Salud','Medicina Humana',3,'Histología'),
('Facultad de Ciencias de la Salud','Medicina Humana',3,'Fisiología'),
('Facultad de Ciencias de la Salud','Medicina Humana',3,'Actividades de Proyección Social I'),
('Facultad de Ciencias de la Salud','Medicina Humana',4,'Inmunología'),
('Facultad de Ciencias de la Salud','Medicina Humana',4,'Bioquímica'),
('Facultad de Ciencias de la Salud','Medicina Humana',4,'Microbiología y parasitología'),
('Facultad de Ciencias de la Salud','Medicina Humana',4,'Aparato locomotor'),
('Facultad de Ciencias de la Salud','Medicina Humana',4,'Sistema tegumentario'),
('Facultad de Ciencias de la Salud','Medicina Humana',4,'Sistema endocrino'),
('Facultad de Ciencias de la Salud','Medicina Humana',4,'Actividades de Proyección Social II'),
('Facultad de Ciencias de la Salud','Medicina Humana',5,'Farmacología'),
('Facultad de Ciencias de la Salud','Medicina Humana',5,'Patología'),
('Facultad de Ciencias de la Salud','Medicina Humana',5,'Sistema digestivo'),
('Facultad de Ciencias de la Salud','Medicina Humana',5,'Sistema cardiovascular y linfático'),
('Facultad de Ciencias de la Salud','Medicina Humana',5,'Sistema respiratorio'),
('Facultad de Ciencias de la Salud','Medicina Humana',5,'Tecnología de información en salud'),
('Facultad de Ciencias de la Salud','Medicina Humana',5,'Actividades de Proyección Social III'),
('Facultad de Ciencias de la Salud','Medicina Humana',6,'Nutrición y metabolismo'),
('Facultad de Ciencias de la Salud','Medicina Humana',6,'Epidemiología Básica'),
('Facultad de Ciencias de la Salud','Medicina Humana',6,'Aparato excretor y reproductor'),
('Facultad de Ciencias de la Salud','Medicina Humana',6,'Sistema nervioso'),
('Facultad de Ciencias de la Salud','Medicina Humana',6,'Psicología médica'),
('Facultad de Ciencias de la Salud','Medicina Humana',6,'Inglés I'),
('Facultad de Ciencias de la Salud','Medicina Humana',7,'Estrategias sanitarias'),
('Facultad de Ciencias de la Salud','Medicina Humana',7,'Introducción a la clínica'),
('Facultad de Ciencias de la Salud','Medicina Humana',7,'Taller de Investigación I'),
('Facultad de Ciencias de la Salud','Medicina Humana',7,'Inglés II'),
('Facultad de Ciencias de la Salud','Medicina Humana',7,'Bioética'),
('Facultad de Ciencias de la Salud','Medicina Humana',7,'Epidemiología Clínica'),
('Facultad de Ciencias de la Salud','Medicina Humana',8,'Genética de la enfermedad'),
('Facultad de Ciencias de la Salud','Medicina Humana',8,'Clínica quirúrgica I'),
('Facultad de Ciencias de la Salud','Medicina Humana',8,'Clínica médica I'),
('Facultad de Ciencias de la Salud','Medicina Humana',8,'Inglés III'),
('Facultad de Ciencias de la Salud','Medicina Humana',8,'Taller de Investigación II'),
('Facultad de Ciencias de la Salud','Medicina Humana',8,'Clínica Pediátrica'),
('Facultad de Ciencias de la Salud','Medicina Humana',9,'Clínica quirúrgica II'),
('Facultad de Ciencias de la Salud','Medicina Humana',9,'Clínica médica II'),
('Facultad de Ciencias de la Salud','Medicina Humana',9,'Proyecto de tesis'),
('Facultad de Ciencias de la Salud','Medicina Humana',9,'Clínica Gineco obstetra I'),
('Facultad de Ciencias de la Salud','Medicina Humana',9,'Clínica de las especialidades pediátricas'),
('Facultad de Ciencias de la Salud','Medicina Humana',10,'Clínica Gineco obstetra II'),
('Facultad de Ciencias de la Salud','Medicina Humana',10,'Medicina legal'),
('Facultad de Ciencias de la Salud','Medicina Humana',10,'Desarrollo de tesis'),
('Facultad de Ciencias de la Salud','Medicina Humana',10,'Electivo'),
('Facultad de Ciencias de la Salud','Medicina Humana',10,'Clínica Neurólogica'),
('Facultad de Ciencias de la Salud','Medicina Humana',11,'Externado de Cirugía'),
('Facultad de Ciencias de la Salud','Medicina Humana',11,'Externado de medicina'),
('Facultad de Ciencias de la Salud','Medicina Humana',11,'Electivo'),
('Facultad de Ciencias de la Salud','Medicina Humana',12,'Externado Ginecobstetra'),
('Facultad de Ciencias de la Salud','Medicina Humana',12,'Externado de pediatría'),
('Facultad de Ciencias de la Salud','Medicina Humana',12,'Electivo'),
('Facultad de Ciencias de la Salud','Medicina Humana',13,'Internado de Medicina'),
('Facultad de Ciencias de la Salud','Medicina Humana',13,'Internado de Cirugía'),
('Facultad de Ciencias de la Salud','Medicina Humana',14,'Internado de Pediatría'),
('Facultad de Ciencias de la Salud','Medicina Humana',14,'Internado Ginecobstetra')
on conflict do nothing;

-- Vista previa: cursos oficiales por carrera/ciclo según brochures
select career_name as carrera, cycle_number as ciclo, count(*) as cursos_pdf
from tmp_uai_official_courses
group by career_name, cycle_number
order by career_name, cycle_number;

-- Cursos actualmente activos en Supabase que NO existen en los brochures cargados
create temporary table tmp_uai_courses_to_disable as
select c.id as course_id, ca.name as career_name, cy.order_number as cycle_number, c.name as course_name
from public.courses c
join public.careers ca on ca.id = c.career_id
join public.faculties f on f.id = ca.faculty_id
join public.universities u on u.id = f.university_id
join public.cycles cy on cy.id = c.cycle_id
join (select distinct faculty_name, career_name from tmp_uai_official_courses) scoped
  on public.mnf_norm(scoped.career_name) = public.mnf_norm(ca.name)
 and public.mnf_norm(scoped.faculty_name) = public.mnf_norm(f.name)
where public.mnf_norm(u.code)=public.mnf_norm('UAI')
  and c.status = 'active'
  and not exists (
    select 1 from tmp_uai_official_courses o
    where public.mnf_norm(o.career_name)=public.mnf_norm(ca.name)
      and public.mnf_norm(o.faculty_name)=public.mnf_norm(f.name)
      and o.cycle_number=cy.order_number
      and public.mnf_norm(o.course_name)=public.mnf_norm(c.name)
  );

select * from tmp_uai_courses_to_disable order by career_name, cycle_number, course_name;

-- Aplicar: resolver cursos oficiales sin duplicar por contexto + nombre normalizado.
drop table if exists tmp_uai_target_courses;
create temporary table tmp_uai_target_courses as
with official_raw as (
  select
    u.id as university_id,
    f.id as faculty_id,
    ca.id as career_id,
    cy.id as cycle_id,
    o.course_name,
    public.mnf_norm(o.course_name) as norm_course_name,
    lower(trim(o.course_name)) as lower_course_name,
    et.id as template_id
  from tmp_uai_official_courses o
  join public.universities u on public.mnf_norm(u.code)=public.mnf_norm('UAI')
  join public.faculties f on f.university_id=u.id and public.mnf_norm(f.name)=public.mnf_norm(o.faculty_name)
  join public.careers ca on ca.faculty_id=f.id and public.mnf_norm(ca.name)=public.mnf_norm(o.career_name)
  join public.cycles cy on cy.order_number=o.cycle_number
  left join public.evaluation_templates et on et.university_id=u.id and public.mnf_norm(et.name)=public.mnf_norm('UAI - Evaluación por unidades')
)
select distinct on (university_id, faculty_id, career_id, cycle_id, norm_course_name)
  university_id,
  faculty_id,
  career_id,
  cycle_id,
  course_name,
  norm_course_name,
  lower_course_name,
  template_id
from official_raw
order by university_id, faculty_id, career_id, cycle_id, norm_course_name, course_name;

-- Aplicar: actualizar/reactivar cursos que ya existen en el brochure.
-- Si el curso existe como inactive, se reactiva. Si existe con nombre sin tilde
-- o distinto uso de mayúsculas, se renombra al nombre oficial.
update public.courses c
set
  university_id=o.university_id,
  faculty_id=o.faculty_id,
  career_id=o.career_id,
  cycle_id=o.cycle_id,
  name=o.course_name,
  evaluation_template_id=o.template_id,
  status='active',
  updated_at=now()
from tmp_uai_target_courses o
where (select do_apply from tmp_config)
  and c.university_id=o.university_id
  and c.faculty_id=o.faculty_id
  and c.career_id=o.career_id
  and c.cycle_id=o.cycle_id
  and (
    public.mnf_norm(c.name)=o.norm_course_name
    or lower(trim(c.name))=o.lower_course_name
  )
  and not exists (
    select 1
    from public.courses other
    where other.id <> c.id
      and other.university_id=o.university_id
      and other.faculty_id=o.faculty_id
      and other.career_id=o.career_id
      and other.cycle_id=o.cycle_id
      and lower(trim(other.name))=o.lower_course_name
  );

-- Aplicar: insertar solo cursos que realmente no existen.
-- No se valida solo active; si existe inactive, debe reactivarse, no duplicarse.
insert into public.courses (university_id, faculty_id, career_id, cycle_id, name, created_by, status, evaluation_template_id, created_at, updated_at)
select o.university_id, o.faculty_id, o.career_id, o.cycle_id, o.course_name, null, 'active', o.template_id, now(), now()
from tmp_uai_target_courses o
where (select do_apply from tmp_config)
  and not exists (
    select 1 from public.courses c
    where c.university_id=o.university_id
      and c.faculty_id=o.faculty_id
      and c.career_id=o.career_id
      and c.cycle_id=o.cycle_id
      and (
        public.mnf_norm(c.name)=o.norm_course_name
        or lower(trim(c.name))=o.lower_course_name
      )
  )
on conflict do nothing;

-- Aplicar: eliminar de la vista oficial los cursos que NO están en brochure.
-- Se usa baja lógica para no romper historial/notas de alumnos. No aparecerán como cursos activos.
update public.courses c
set status='inactive', updated_at=now()
from tmp_uai_courses_to_disable d
where (select do_apply from tmp_config)
  and c.id=d.course_id;

-- Validación final: después de aplicar, los cursos activos deben coincidir con el PDF
select ca.name as carrera, cy.order_number as ciclo, count(c.id) as cursos_activos
from public.courses c
join public.careers ca on ca.id=c.career_id
join public.faculties f on f.id=ca.faculty_id
join public.universities u on u.id=f.university_id
join public.cycles cy on cy.id=c.cycle_id
join (select distinct faculty_name, career_name from tmp_uai_official_courses) scoped
  on public.mnf_norm(scoped.career_name)=public.mnf_norm(ca.name)
 and public.mnf_norm(scoped.faculty_name)=public.mnf_norm(f.name)
where public.mnf_norm(u.code)=public.mnf_norm('UAI')
  and c.status='active'
group by ca.name, cy.order_number
order by ca.name, cy.order_number;

-- Si do_apply=false, no se hizo ningún cambio. Si do_apply=true, confirma la transacción.
commit;

-- ============================================================
-- FIN DEL SCRIPT CONSOLIDADO
-- Validación rápida sugerida después de ejecutar:
--
-- select u.code, ca.name as carrera, cy.order_number as ciclo, count(*) as cursos_activos
-- from public.courses c
-- join public.universities u on u.id = c.university_id
-- join public.careers ca on ca.id = c.career_id
-- join public.cycles cy on cy.id = c.cycle_id
-- where c.status = 'active'
--   and u.code in ('UPSJB', 'UAI')
-- group by u.code, ca.name, cy.order_number
-- order by u.code, ca.name, cy.order_number;
-- ============================================================
