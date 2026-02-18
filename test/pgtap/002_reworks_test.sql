-- Tests pgTAP para verificar los reworks de v0.2.0:
--   - lawyers: columnas first_name y last_name
--   - appointments: exclusion constraint parcial (excluye canceladas)
--
-- Ejecutar con: make test

BEGIN;

SELECT plan(12);

-- ============================================
-- lawyers: nuevas columnas
-- ============================================

SELECT has_column('lawyers', 'first_name',
    'lawyers.first_name existe');

SELECT has_column('lawyers', 'last_name',
    'lawyers.last_name existe');

SELECT col_not_null('lawyers', 'first_name',
    'lawyers.first_name es NOT NULL');

SELECT col_not_null('lawyers', 'last_name',
    'lawyers.last_name es NOT NULL');

SELECT col_type_is('lawyers', 'first_name', 'text',
    'lawyers.first_name es TEXT');

SELECT col_type_is('lawyers', 'last_name', 'text',
    'lawyers.last_name es TEXT');

-- ============================================
-- appointments: exclusion constraint parcial
-- ============================================

SELECT is(
    (SELECT COUNT(*)::INT FROM pg_constraint
     WHERE conname = 'excl_appointments_no_overlap'
       AND contype = 'x'),
    1,
    'Exclusion constraint excl_appointments_no_overlap existe'
);

SELECT matches(
    (SELECT pg_get_constraintdef(oid)
     FROM pg_constraint
     WHERE conname = 'excl_appointments_no_overlap'),
    'WHERE',
    'Exclusion constraint tiene clausula WHERE'
);

-- ============================================
-- Test funcional: canceladas pueden solapar
-- ============================================

-- Datos de test aislados (IDs altos)
INSERT INTO organizations (id, name, country, timezone)
OVERRIDING SYSTEM VALUE VALUES (50001, 'Test Org Rework', 'Test', 'UTC');

INSERT INTO users (id, email, auth_provider)
OVERRIDING SYSTEM VALUE VALUES
    (50001, 'test-rework-lawyer@test.com', 'local'),
    (50002, 'test-rework-client@test.com', 'local');

INSERT INTO lawyers (id, user_id, first_name, last_name)
OVERRIDING SYSTEM VALUE VALUES (50001, 50001, 'Test', 'Lawyer');

INSERT INTO client_profiles (id, user_id, organization_id, first_name, last_name)
OVERRIDING SYSTEM VALUE VALUES (50001, 50002, 50001, 'Test', 'Client');

INSERT INTO appointment_types (id, organization_id, name, duration_minutes, modality)
OVERRIDING SYSTEM VALUE VALUES (50001, 50001, 'Test Type', 60, 'video');

-- Cita cancelada
INSERT INTO appointments (organization_id, lawyer_id, client_profile_id,
    appointment_type_id, starts_at, ends_at, status)
VALUES (50001, 50001, 50001, 50001,
    '2099-06-01 09:00:00+00', '2099-06-01 10:00:00+00', 'cancelled');

-- Otra cita en el mismo slot: debe funcionar (cancelada no bloquea)
SELECT lives_ok(
    $$INSERT INTO appointments (organization_id, lawyer_id, client_profile_id,
        appointment_type_id, starts_at, ends_at, status)
      VALUES (50001, 50001, 50001, 50001,
        '2099-06-01 09:00:00+00', '2099-06-01 10:00:00+00', 'pending')$$,
    'Se puede reservar sobre una cita cancelada'
);

-- Tercera cita en el mismo slot: debe fallar (pending + pending = solapamiento)
SELECT throws_ok(
    $$INSERT INTO appointments (organization_id, lawyer_id, client_profile_id,
        appointment_type_id, starts_at, ends_at, status)
      VALUES (50001, 50001, 50001, 50001,
        '2099-06-01 09:00:00+00', '2099-06-01 10:00:00+00', 'confirmed')$$,
    '23P01',
    NULL,
    'No se puede hacer doble booking en el mismo slot (ambos no-cancelados)'
);

-- Verificar que el indice principal sigue existiendo
SELECT has_index('appointments', 'idx_appointments_lawyer_date',
    'Indice idx_appointments_lawyer_date sigue existiendo');

-- Una cita cancelada puede solapar con otra cancelada
SELECT lives_ok(
    $$INSERT INTO appointments (organization_id, lawyer_id, client_profile_id,
        appointment_type_id, starts_at, ends_at, status)
      VALUES (50001, 50001, 50001, 50001,
        '2099-06-01 09:00:00+00', '2099-06-01 10:00:00+00', 'cancelled')$$,
    'Dos citas canceladas pueden solapar'
);

SELECT * FROM finish();

ROLLBACK;
