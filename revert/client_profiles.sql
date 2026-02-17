-- Revert fontanella:client_profiles from pg
BEGIN;
DROP TABLE IF EXISTS client_profiles;
COMMIT;
