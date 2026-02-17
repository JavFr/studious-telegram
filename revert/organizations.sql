-- Revert fontanella:organizations from pg
BEGIN;
DROP TABLE IF EXISTS organizations;
COMMIT;
