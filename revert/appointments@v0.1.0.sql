-- Revert fontanella:appointments from pg
BEGIN;
DROP TABLE IF EXISTS appointments;
COMMIT;
