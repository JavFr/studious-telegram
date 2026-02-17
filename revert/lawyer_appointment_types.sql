-- Revert fontanella:lawyer_appointment_types from pg
BEGIN;
DROP TABLE IF EXISTS lawyer_appointment_types;
COMMIT;
