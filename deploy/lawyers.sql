-- Deploy fontanella:lawyers to pg (rework: agregar first_name y last_name)
BEGIN;
ALTER TABLE lawyers
    ADD COLUMN first_name TEXT NOT NULL DEFAULT '',
    ADD COLUMN last_name TEXT NOT NULL DEFAULT '';
ALTER TABLE lawyers
    ALTER COLUMN first_name DROP DEFAULT,
    ALTER COLUMN last_name DROP DEFAULT;
COMMIT;
