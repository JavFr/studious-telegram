-- Revert fontanella:extensions from pg
BEGIN;
DROP EXTENSION IF EXISTS btree_gist;
COMMIT;
