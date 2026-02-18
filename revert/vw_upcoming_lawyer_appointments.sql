-- Revert fontanella:vw_upcoming_lawyer_appointments from pg
BEGIN;
DROP VIEW IF EXISTS vw_upcoming_lawyer_appointments;
COMMIT;
