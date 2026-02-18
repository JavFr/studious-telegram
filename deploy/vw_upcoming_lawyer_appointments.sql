-- Deploy fontanella:vw_upcoming_lawyer_appointments to pg
--
-- Vista de proximas citas desde la perspectiva del abogado.
-- Incluye datos enriquecidos del cliente, tipo de cita y organizacion.
-- Filtrar por lawyer_id para obtener las citas de un abogado.
BEGIN;
CREATE OR REPLACE VIEW vw_upcoming_lawyer_appointments AS
SELECT
    a.id AS appointment_id,
    a.lawyer_id,
    a.starts_at,
    a.ends_at,
    a.status,
    a.notes,
    a.created_at,
    -- Cliente
    cp.id AS client_profile_id,
    cp.first_name AS client_first_name,
    cp.last_name AS client_last_name,
    cp.phone AS client_phone,
    -- Tipo de cita
    at.name AS type_name,
    at.duration_minutes,
    at.modality,
    -- Organizacion
    o.id AS organization_id,
    o.name AS organization_name,
    o.timezone AS organization_timezone
FROM
    appointments a
    JOIN client_profiles cp ON cp.id = a.client_profile_id
    JOIN appointment_types at ON at.id = a.appointment_type_id
    JOIN organizations o ON o.id = a.organization_id
WHERE
    a.starts_at >= now()
    AND a.status IN ('pending', 'confirmed');
COMMIT;
