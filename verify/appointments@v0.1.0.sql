-- Verify fontanella:appointments on pg
SELECT
    id,
    organization_id,
    lawyer_id,
    client_profile_id,
    appointment_type_id,
    starts_at,
    ends_at,
    status,
    notes,
    created_at,
    updated_at
FROM
    appointments
WHERE
    FALSE;

-- Verificar exclusion constraint
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conrelid = 'appointments'::REGCLASS
    AND contype = 'x';

-- Verificar indice de busqueda
SELECT
    1 / COUNT(*)
FROM
    pg_indexes
WHERE
    indexname = 'idx_appointments_lawyer_date';
