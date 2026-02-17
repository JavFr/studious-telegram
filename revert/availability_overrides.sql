-- Revert fontanella:availability_overrides from pg
BEGIN;
DROP TABLE IF EXISTS availability_overrides;
COMMIT;
