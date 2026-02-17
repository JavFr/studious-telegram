-- Deploy fontanella:extensions to pg
BEGIN;
CREATE EXTENSION IF NOT EXISTS btree_gist;
COMMIT;
