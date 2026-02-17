-- Revert fontanella:appointment_types from pg
BEGIN;
DROP TABLE IF EXISTS appointment_types;
COMMIT;
