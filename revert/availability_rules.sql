-- Revert fontanella:availability_rules from pg
BEGIN;
DROP TABLE IF EXISTS availability_rules;
COMMIT;
