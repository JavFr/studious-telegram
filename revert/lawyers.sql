-- Revert fontanella:lawyers from pg (rework: quitar first_name y last_name)
BEGIN;
ALTER TABLE lawyers
    DROP COLUMN first_name,
    DROP COLUMN last_name;
COMMIT;
