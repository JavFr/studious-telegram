-- Revert fontanella:users from pg
BEGIN;
DROP TABLE IF EXISTS users;
COMMIT;
