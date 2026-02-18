-- Tests pgTAP para vistas de v0.2.0:
--   - vw_upcoming_client_appointments
--   - vw_upcoming_lawyer_appointments
--
-- Datos de test autocontenidos (IDs 60000+). Todo dentro de BEGIN/ROLLBACK.
--
-- Ejecutar con: make test

BEGIN;

SELECT plan(6);

-- ============================================
-- Existencia de objetos
-- ============================================

SELECT has_view('vw_upcoming_client_appointments',
    'Vista vw_upcoming_client_appointments existe');

SELECT has_view('vw_upcoming_lawyer_appointments',
    'Vista vw_upcoming_lawyer_appointments existe');

-- ============================================
-- Setup: datos de test aislados
-- ============================================

-- Organizacion
INSERT INTO organizations (id, name, country, timezone)
OVERRIDING SYSTEM VALUE VALUES
    (60001, 'Test Org Views', 'Argentina', 'America/Argentina/Buenos_Aires');

-- Usuarios
INSERT INTO users (id, email, auth_provider)
OVERRIDING SYSTEM VALUE VALUES
    (60001, 'vw-lawyer@test.com', 'local'),
    (60002, 'vw-client@test.com', 'local');

-- Abogado
INSERT INTO lawyers (id, user_id, first_name, last_name, specialty)
OVERRIDING SYSTEM VALUE VALUES
    (60001, 60001, 'TestName', 'TestLastName', 'Derecho Test');

-- Cliente
INSERT INTO client_profiles (id, user_id, organization_id, first_name, last_name, phone)
OVERRIDING SYSTEM VALUE VALUES
    (60001, 60002, 60001, 'ClienteTest', 'ApellidoTest', '+54 11 0000-0000');

-- Tipo de cita
INSERT INTO appointment_types (id, organization_id, name, duration_minutes, modality, is_active)
OVERRIDING SYSTEM VALUE VALUES
    (60001, 60001, 'Consulta Test', 60, 'presencial', true);

-- Cita futura pending (aparece en ambas vistas)
INSERT INTO appointments (organization_id, lawyer_id, client_profile_id,
    appointment_type_id, starts_at, ends_at, status, notes)
VALUES (60001, 60001, 60001, 60001,
    '2099-06-15 09:00:00+00', '2099-06-15 10:00:00+00', 'pending', 'Nota test');

-- Cita futura cancelada (NO aparece en vistas)
INSERT INTO appointments (organization_id, lawyer_id, client_profile_id,
    appointment_type_id, starts_at, ends_at, status)
VALUES (60001, 60001, 60001, 60001,
    '2099-06-16 09:00:00+00', '2099-06-16 10:00:00+00', 'cancelled');

-- ============================================
-- vw_upcoming_client_appointments
-- ============================================

SELECT is(
    (SELECT COUNT(*)::INT
     FROM vw_upcoming_client_appointments
     WHERE client_profile_id = 60001
       AND type_name = 'Consulta Test'),
    1,
    'vw_upcoming_client_appointments: muestra cita futura pending'
);

SELECT is(
    (SELECT lawyer_first_name
     FROM vw_upcoming_client_appointments
     WHERE client_profile_id = 60001),
    'TestName',
    'vw_upcoming_client_appointments: incluye nombre del abogado'
);

-- ============================================
-- vw_upcoming_lawyer_appointments
-- ============================================

SELECT is(
    (SELECT COUNT(*)::INT
     FROM vw_upcoming_lawyer_appointments
     WHERE lawyer_id = 60001
       AND client_first_name = 'ClienteTest'),
    1,
    'vw_upcoming_lawyer_appointments: muestra cita con datos del cliente'
);

SELECT is(
    (SELECT organization_name
     FROM vw_upcoming_lawyer_appointments
     WHERE lawyer_id = 60001),
    'Test Org Views',
    'vw_upcoming_lawyer_appointments: incluye nombre de organizacion'
);

SELECT * FROM finish();

ROLLBACK;
