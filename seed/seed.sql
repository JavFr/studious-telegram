-- ============================================
-- Fontanella — Datos base determinísticos
-- ============================================
--
-- Datos conocidos para desarrollo local y tests manuales.
-- Cubre edge cases: back-to-back, near-boundary, todos los statuses,
-- múltiples timezones, availability overrides.
--
-- Uso:
--   make seed          (carga estos datos)
--   make seed-reset    (limpia todo y recarga)
--
-- IMPORTANTE: Este archivo usa OVERRIDING SYSTEM VALUE para forzar IDs.
-- Las secuencias se resetean al final para evitar conflictos con el
-- generador de volumen.
--

-- Guardia contra doble ejecución
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM organizations LIMIT 1) THEN
        RAISE EXCEPTION
            'La base de datos ya contiene datos. Ejecutá "make seed-reset" primero.';
    END IF;
END $$;

BEGIN;

-- ============================================
-- 1. Organizaciones (3 países, 3 timezones)
-- ============================================

INSERT INTO organizations (id, name, country, timezone, address)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'Estudio Pérez & Asociados', 'Argentina',
     'America/Argentina/Buenos_Aires', 'Av. Corrientes 1234, CABA'),
    (2, 'Bufete Morales', 'México',
     'America/Mexico_City', 'Paseo de la Reforma 500, CDMX'),
    (3, 'Despacho Fernández', 'España',
     'Europe/Madrid', 'Calle Serrano 45, Madrid');

-- ============================================
-- 2. Usuarios
-- ============================================
-- IDs 1-2:  admin/secretaria (no son abogados)
-- IDs 3-7:  abogados
-- IDs 8-13: clientes

INSERT INTO users (id, email, auth_provider)
OVERRIDING SYSTEM VALUE
VALUES
    -- Staff org 1
    (1,  'admin@estudio-perez.com.ar',       'local'),
    (2,  'secretaria@estudio-perez.com.ar',   'local'),
    -- Abogados
    (3,  'garcia.rodrigo@estudio-perez.com.ar', 'local'),
    (4,  'lopez.marta@estudio-perez.com.ar',    'local'),
    (5,  'morales.diego@bufete-morales.mx',      'google'),
    (6,  'reyes.ana@bufete-morales.mx',          'local'),
    (7,  'fernandez.carlos@despacho-fdez.es',    'local'),
    -- Clientes
    (8,  'juan.martinez@gmail.com',    'local'),
    (9,  'maria.gonzalez@gmail.com',   'local'),
    (10, 'roberto.silva@hotmail.com',  'local'),
    (11, 'lucia.ramirez@gmail.com',    'google'),
    (12, 'pedro.hernandez@yahoo.com',  'local'),
    (13, 'elena.ruiz@gmail.com',       'firebase');

-- ============================================
-- 3. Membresías (roles por organización)
-- ============================================
-- UNIQUE(user_id, organization_id): un usuario tiene un solo rol por org.

INSERT INTO organization_members (user_id, organization_id, role)
VALUES
    (1, 1, 'admin'),
    (2, 1, 'secretary'),
    (3, 1, 'lawyer'),
    (4, 1, 'lawyer'),
    (5, 2, 'lawyer'),
    (6, 2, 'lawyer'),
    (7, 3, 'lawyer');

-- ============================================
-- 4. Abogados (perfil profesional global)
-- ============================================

INSERT INTO lawyers (id, user_id, license_number, specialty)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 3, 'CPACF-1042',    'Derecho de Familia y Sucesiones'),
    (2, 4, 'CPACF-2203',    'Derecho Laboral'),
    (3, 5, 'BARRA-MX-3317', 'Derecho Corporativo'),
    (4, 6, 'BARRA-MX-4481', 'Derecho Penal'),
    (5, 7, 'ICAM-5590',     'Derecho Civil');

-- ============================================
-- 5. Perfiles de clientes (por organización)
-- ============================================

INSERT INTO client_profiles
    (id, user_id, organization_id, first_name, last_name, phone, notes)
OVERRIDING SYSTEM VALUE
VALUES
    -- Org 1: Buenos Aires
    (1, 8,  1, 'Juan',    'Martínez',  '+54 11 4444-1111', NULL),
    (2, 9,  1, 'María',   'González',  '+54 11 4444-2222', 'Prefiere turno matutino'),
    (3, 10, 1, 'Roberto', 'Silva',     '+54 11 4444-3333', NULL),
    -- Org 2: CDMX
    (4, 11, 2, 'Lucía',   'Ramírez',   '+52 55 5555-4444', NULL),
    (5, 12, 2, 'Pedro',   'Hernández', '+52 55 5555-5555', 'Cliente corporativo'),
    -- Org 3: Madrid
    (6, 13, 3, 'Elena',   'Ruiz',      '+34 91 666-6666',  NULL);

-- ============================================
-- 6. Tipos de cita (por organización)
-- ============================================

INSERT INTO appointment_types
    (id, organization_id, name, duration_minutes, modality, is_active)
OVERRIDING SYSTEM VALUE
VALUES
    -- Org 1
    (1, 1, 'Consulta inicial',       60, 'presencial', true),
    (2, 1, 'Seguimiento',            30, 'telefonica', true),
    (3, 1, 'Audiencia preparatoria', 90, 'presencial', true),
    -- Org 2
    (4, 2, 'Primera consulta',       60, 'video',      true),
    (5, 2, 'Revisión de contrato',   45, 'video',      true),
    (6, 2, 'Llamada rápida',         15, 'telefonica', true),
    -- Org 3
    (7, 3, 'Consulta presencial',    60, 'presencial', true),
    (8, 3, 'Consulta online',        30, 'video',      true),
    (9, 3, 'Asesoría urgente',       90, 'presencial', false);  -- inactivo

-- ============================================
-- 7. Abogado <-> Tipos de cita (N:N)
-- ============================================

INSERT INTO lawyer_appointment_types (lawyer_id, appointment_type_id)
VALUES
    -- Lawyers org 1 ofrecen todos los tipos de org 1
    (1, 1), (1, 2), (1, 3),
    (2, 1), (2, 2), (2, 3),
    -- Lawyers org 2 ofrecen todos los tipos de org 2
    (3, 4), (3, 5), (3, 6),
    (4, 4), (4, 5), (4, 6),
    -- Lawyer org 3 ofrece todos los tipos de org 3
    (5, 7), (5, 8), (5, 9);

-- ============================================
-- 8. Reglas de disponibilidad (recurrentes)
-- ============================================
-- day_of_week: 0=Domingo, 1=Lunes, ..., 6=Sábado
-- (misma convención que EXTRACT(DOW FROM date) en PostgreSQL)

INSERT INTO availability_rules
    (lawyer_id, organization_id, day_of_week, start_time, end_time, timezone)
VALUES
    -- Lawyer 1 (org 1): Lun-Vie 09:00-17:00 estándar
    (1, 1, 1, '09:00', '17:00', 'America/Argentina/Buenos_Aires'),
    (1, 1, 2, '09:00', '17:00', 'America/Argentina/Buenos_Aires'),
    (1, 1, 3, '09:00', '17:00', 'America/Argentina/Buenos_Aires'),
    (1, 1, 4, '09:00', '17:00', 'America/Argentina/Buenos_Aires'),
    (1, 1, 5, '09:00', '17:00', 'America/Argentina/Buenos_Aires'),

    -- Lawyer 2 (org 1): horario partido
    -- Lun-Mié mañana, Jue-Vie tarde
    (2, 1, 1, '09:00', '13:00', 'America/Argentina/Buenos_Aires'),
    (2, 1, 2, '09:00', '13:00', 'America/Argentina/Buenos_Aires'),
    (2, 1, 3, '09:00', '13:00', 'America/Argentina/Buenos_Aires'),
    (2, 1, 4, '14:00', '18:00', 'America/Argentina/Buenos_Aires'),
    (2, 1, 5, '14:00', '18:00', 'America/Argentina/Buenos_Aires'),

    -- Lawyer 3 (org 2): Lun-Vie 09:00-17:00 estándar
    (3, 2, 1, '09:00', '17:00', 'America/Mexico_City'),
    (3, 2, 2, '09:00', '17:00', 'America/Mexico_City'),
    (3, 2, 3, '09:00', '17:00', 'America/Mexico_City'),
    (3, 2, 4, '09:00', '17:00', 'America/Mexico_City'),
    (3, 2, 5, '09:00', '17:00', 'America/Mexico_City'),

    -- Lawyer 4 (org 2): jornada larga + viernes corto
    -- Lun-Jue 10:00-19:00, Vie 10:00-14:00
    (4, 2, 1, '10:00', '19:00', 'America/Mexico_City'),
    (4, 2, 2, '10:00', '19:00', 'America/Mexico_City'),
    (4, 2, 3, '10:00', '19:00', 'America/Mexico_City'),
    (4, 2, 4, '10:00', '19:00', 'America/Mexico_City'),
    (4, 2, 5, '10:00', '14:00', 'America/Mexico_City'),

    -- Lawyer 5 (org 3): Lun-Vie 09:00-17:00 estándar
    (5, 3, 1, '09:00', '17:00', 'Europe/Madrid'),
    (5, 3, 2, '09:00', '17:00', 'Europe/Madrid'),
    (5, 3, 3, '09:00', '17:00', 'Europe/Madrid'),
    (5, 3, 4, '09:00', '17:00', 'Europe/Madrid'),
    (5, 3, 5, '09:00', '17:00', 'Europe/Madrid');

-- ============================================
-- 9. Excepciones de disponibilidad
-- ============================================
-- NULL en start_time/end_time = bloqueo/disponibilidad de día completo.

INSERT INTO availability_overrides
    (lawyer_id, organization_id, date, start_time, end_time, is_available, reason)
VALUES
    -- Lawyer 1: vacaciones 20-24 enero 2026 (bloques de día completo)
    (1, 1, '2026-01-20', NULL, NULL, false, 'Vacaciones enero'),
    (1, 1, '2026-01-21', NULL, NULL, false, 'Vacaciones enero'),
    (1, 1, '2026-01-22', NULL, NULL, false, 'Vacaciones enero'),
    (1, 1, '2026-01-23', NULL, NULL, false, 'Vacaciones enero'),
    (1, 1, '2026-01-24', NULL, NULL, false, 'Vacaciones enero'),

    -- Lawyer 2: guardia especial sábado 28 feb 2026
    (2, 1, '2026-02-28', '09:00', '13:00', true, 'Guardia especial sábado'),

    -- Lawyer 3: feriado México 21 marzo (Natalicio Benito Juárez)
    (3, 2, '2026-03-21', NULL, NULL, false, 'Feriado — Natalicio de Benito Juárez'),

    -- Lawyer 4: horario extendido viernes 6 marzo 2026
    (4, 2, '2026-03-06', '14:00', '20:00', true, 'Horario extendido por evento');

-- ============================================
-- 10. Citas
-- ============================================
-- Los timestamps se expresan como hora local convertida a TIMESTAMPTZ
-- usando AT TIME ZONE, que es la forma correcta de decir "esta hora
-- naive es en esta timezone, dame el instante UTC correspondiente".
--
-- IMPORTANTE: El EXCLUDE USING GIST aplica a TODAS las filas sin
-- importar el status. No se pueden solapar dos citas del mismo
-- abogado, incluso si una está cancelada.

INSERT INTO appointments
    (id, organization_id, lawyer_id, client_profile_id, appointment_type_id,
     starts_at, ends_at, status, notes)
OVERRIDING SYSTEM VALUE
VALUES
    -- ── Org 1, Lawyer 1 (Buenos Aires, UTC-3) ──────────────────

    -- Consulta completada
    (1, 1, 1, 1, 1,
     '2025-11-10 09:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     '2025-11-10 10:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     'completed', 'Primera consulta caso divorcio'),

    -- Back-to-back: empieza exactamente donde termina la anterior
    -- tstzrange [) half-open: [09:00,10:00) y [10:00,10:30) NO se solapan
    (2, 1, 1, 2, 2,
     '2025-11-10 10:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     '2025-11-10 10:30'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     'completed', 'Seguimiento inmediato post-consulta'),

    -- No show
    (3, 1, 1, 3, 3,
     '2025-12-03 09:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     '2025-12-03 10:30'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     'no_show', NULL),

    -- Near-boundary: termina justo al cierre de la jornada (17:00)
    (4, 1, 1, 1, 2,
     '2026-01-15 16:30'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     '2026-01-15 17:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     'confirmed', 'Consulta fin de jornada'),

    -- ── Org 1, Lawyer 2 (Buenos Aires, UTC-3) ──────────────────

    -- Turno confirmado en horario mañana (Lun-Mié 09-13)
    (5, 1, 2, 2, 1,
     '2026-02-04 09:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     '2026-02-04 10:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     'confirmed', NULL),

    -- Cancelado
    (6, 1, 2, 3, 2,
     '2025-12-15 09:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     '2025-12-15 09:30'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     'cancelled', 'Canceló el cliente por enfermedad'),

    -- Pendiente futuro
    (7, 1, 2, 1, 1,
     '2026-03-16 09:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     '2026-03-16 10:00'::TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires',
     'pending', 'Próxima consulta'),

    -- ── Org 2, Lawyer 3 (CDMX, UTC-6) ─────────────────────────

    -- Completada
    (8, 2, 3, 4, 4,
     '2025-11-20 09:00'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     '2025-11-20 10:00'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     'completed', 'Consulta societaria inicial'),

    -- Pendiente
    (9, 2, 3, 5, 5,
     '2026-03-05 09:00'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     '2026-03-05 09:45'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     'pending', 'Revisión contrato de arrendamiento'),

    -- ── Org 2, Lawyer 4 (CDMX, UTC-6) ─────────────────────────

    -- Back-to-back: consulta 60min + llamada rápida 15min
    (10, 2, 4, 4, 4,
     '2026-02-19 10:00'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     '2026-02-19 11:00'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     'confirmed', NULL),

    (11, 2, 4, 5, 6,
     '2026-02-19 11:00'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     '2026-02-19 11:15'::TIMESTAMP AT TIME ZONE 'America/Mexico_City',
     'confirmed', 'Llamada rápida post-reunión'),

    -- ── Org 3, Lawyer 5 (Madrid, UTC+1 invierno / UTC+2 verano) ─

    -- Invierno (UTC+1): local 09:00 = UTC 08:00
    (12, 3, 5, 6, 7,
     '2025-12-01 09:00'::TIMESTAMP AT TIME ZONE 'Europe/Madrid',
     '2025-12-01 10:00'::TIMESTAMP AT TIME ZONE 'Europe/Madrid',
     'completed', 'Asesoría herencia'),

    -- Todavía invierno (DST empieza último domingo de marzo = 29 mar 2026)
    (13, 3, 5, 6, 8,
     '2026-03-10 10:00'::TIMESTAMP AT TIME ZONE 'Europe/Madrid',
     '2026-03-10 10:30'::TIMESTAMP AT TIME ZONE 'Europe/Madrid',
     'pending', 'Consulta online seguimiento');

-- ============================================
-- 11. Resetear secuencias
-- ============================================
-- Avanza cada secuencia al MAX(id) de su tabla para que el generador
-- de volumen (o INSERTs manuales) no colisionen con los IDs forzados.

SELECT setval(pg_get_serial_sequence('organizations',          'id'), (SELECT MAX(id) FROM organizations));
SELECT setval(pg_get_serial_sequence('users',                  'id'), (SELECT MAX(id) FROM users));
SELECT setval(pg_get_serial_sequence('organization_members',   'id'), (SELECT MAX(id) FROM organization_members));
SELECT setval(pg_get_serial_sequence('lawyers',                'id'), (SELECT MAX(id) FROM lawyers));
SELECT setval(pg_get_serial_sequence('client_profiles',        'id'), (SELECT MAX(id) FROM client_profiles));
SELECT setval(pg_get_serial_sequence('appointment_types',      'id'), (SELECT MAX(id) FROM appointment_types));
SELECT setval(pg_get_serial_sequence('availability_rules',     'id'), (SELECT MAX(id) FROM availability_rules));
SELECT setval(pg_get_serial_sequence('availability_overrides', 'id'), (SELECT MAX(id) FROM availability_overrides));
SELECT setval(pg_get_serial_sequence('appointments',           'id'), (SELECT MAX(id) FROM appointments));

COMMIT;
