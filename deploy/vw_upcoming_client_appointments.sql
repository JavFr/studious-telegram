-- Deploy fontanella:vw_upcoming_client_appointments to pg
--
-- Vista de proximas citas desde la perspectiva del cliente.
-- Incluye datos enriquecidos del abogado, tipo de cita y organizacion.
-- Filtrar por client_profile_id para obtener las citas de un cliente.
BEGIN;
CREATE OR REPLACE VIEW vw_upcoming_client_appointments AS
SELECT
    a.id AS appointment_id,
    a.client_profile_id,
    a.starts_at,
    a.ends_at,
    a.status,
    a.notes,
    a.created_at,
    -- Abogado
    l.id AS lawyer_id,
    l.first_name AS lawyer_first_name,
    l.last_name AS lawyer_last_name,
    l.specialty AS lawyer_specialty,
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
    JOIN lawyers l ON l.id = a.lawyer_id
    JOIN appointment_types at ON at.id = a.appointment_type_id
    JOIN organizations o ON o.id = a.organization_id
WHERE
    a.starts_at >= now()
    AND a.status IN ('pending', 'confirmed');
COMMIT;
