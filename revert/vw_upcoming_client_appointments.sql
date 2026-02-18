-- Revert fontanella:vw_upcoming_client_appointments from pg
BEGIN;
DROP VIEW IF EXISTS vw_upcoming_client_appointments;
COMMIT;
