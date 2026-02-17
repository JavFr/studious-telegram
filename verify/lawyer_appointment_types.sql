-- Verify fontanella:lawyer_appointment_types on pg
SELECT
    lawyer_id,
    appointment_type_id
FROM
    lawyer_appointment_types
WHERE
    FALSE;

-- Composite PK
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conname = 'lawyer_appointment_types_pkey';
