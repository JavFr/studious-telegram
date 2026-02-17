-- Revert fontanella:organization_members from pg
BEGIN;
DROP TABLE IF EXISTS organization_members;
COMMIT;
