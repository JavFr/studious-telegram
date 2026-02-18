-- Revert fontanella:lawyers from pg
BEGIN;
DROP TABLE IF EXISTS lawyers;
COMMIT;
