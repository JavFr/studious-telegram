-- Tests pgTAP para verificar el esquema completo de fontanella.
-- Ejecutar con: make test

BEGIN;

SELECT plan(26);

-- ============================================
-- Extensiones
-- ============================================

SELECT has_extension('btree_gist', 'Extension btree_gist instalada');

-- ============================================
-- Tablas existen
-- ============================================

SELECT has_table('users', 'Tabla users existe');
SELECT has_table('organizations', 'Tabla organizations existe');
SELECT has_table('organization_members', 'Tabla organization_members existe');
SELECT has_table('lawyers', 'Tabla lawyers existe');
SELECT has_table('client_profiles', 'Tabla client_profiles existe');
SELECT has_table('appointment_types', 'Tabla appointment_types existe');
SELECT has_table('lawyer_appointment_types', 'Tabla lawyer_appointment_types existe');
SELECT has_table('availability_rules', 'Tabla availability_rules existe');
SELECT has_table('availability_overrides', 'Tabla availability_overrides existe');
SELECT has_table('appointments', 'Tabla appointments existe');

-- ============================================
-- Tipos de columna clave (estrategia de timezones)
-- ============================================

SELECT col_type_is('appointments', 'starts_at', 'timestamp with time zone',
    'appointments.starts_at es TIMESTAMPTZ');
SELECT col_type_is('appointments', 'ends_at', 'timestamp with time zone',
    'appointments.ends_at es TIMESTAMPTZ');
SELECT col_type_is('availability_rules', 'start_time', 'time without time zone',
    'availability_rules.start_time es TIME (hora local)');
SELECT col_type_is('availability_rules', 'end_time', 'time without time zone',
    'availability_rules.end_time es TIME (hora local)');
SELECT col_type_is('availability_rules', 'timezone', 'text',
    'availability_rules.timezone es TEXT (IANA identifier)');

-- ============================================
-- Foreign keys criticas
-- ============================================

SELECT fk_ok('appointments', 'lawyer_id', 'lawyers', 'id',
    'appointments.lawyer_id → lawyers.id');
SELECT fk_ok('appointments', 'client_profile_id', 'client_profiles', 'id',
    'appointments.client_profile_id → client_profiles.id');
SELECT fk_ok('appointments', 'organization_id', 'organizations', 'id',
    'appointments.organization_id → organizations.id');
SELECT fk_ok('appointments', 'appointment_type_id', 'appointment_types', 'id',
    'appointments.appointment_type_id → appointment_types.id');
SELECT fk_ok('organization_members', 'user_id', 'users', 'id',
    'organization_members.user_id → users.id');
SELECT fk_ok('organization_members', 'organization_id', 'organizations', 'id',
    'organization_members.organization_id → organizations.id');

-- ============================================
-- Indice de busqueda principal
-- ============================================

SELECT has_index('appointments', 'idx_appointments_lawyer_date',
    'Indice idx_appointments_lawyer_date existe');

-- ============================================
-- Constraints
-- ============================================

SELECT has_check('appointments', 'appointments tiene CHECK constraint');
SELECT has_check('availability_rules', 'availability_rules tiene CHECK constraint');

-- ============================================
-- Unique constraints
-- ============================================

SELECT col_is_unique('users', 'email', 'users.email es UNIQUE');

SELECT * FROM finish();

ROLLBACK;
