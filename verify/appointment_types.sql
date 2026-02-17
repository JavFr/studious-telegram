-- Verify fontanella:appointment_types on pg
SELECT
    id,
    organization_id,
    name,
    duration_minutes,
    modality,
    is_active,
    created_at
FROM
    appointment_types
WHERE
    FALSE;
