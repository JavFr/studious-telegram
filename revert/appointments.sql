-- Revert fontanella:appointments from pg (rework: restaurar exclusion constraint completo)
BEGIN;
ALTER TABLE appointments
    DROP CONSTRAINT excl_appointments_no_overlap;
ALTER TABLE appointments
    ADD CONSTRAINT appointments_lawyer_id_tstzrange_excl
    EXCLUDE USING GIST (lawyer_id WITH =, tstzrange(starts_at, ends_at) WITH &&);
COMMIT;
