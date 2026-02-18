-- Deploy fontanella:appointments to pg (rework: exclusion constraint parcial)
--
-- Cambia el EXCLUDE USING GIST para que ignore citas canceladas.
-- Esto permite re-agendar un slot que fue cancelado previamente.
BEGIN;
-- Eliminar constraint original (sin nombre explicito, PostgreSQL lo auto-nombro)
ALTER TABLE appointments
    DROP CONSTRAINT appointments_lawyer_id_tstzrange_excl;
-- Recrear con nombre explicito y clausula WHERE
ALTER TABLE appointments
    ADD CONSTRAINT excl_appointments_no_overlap
    EXCLUDE USING GIST (lawyer_id WITH =, tstzrange(starts_at, ends_at) WITH &&)
WHERE (status != 'cancelled');
COMMIT;
