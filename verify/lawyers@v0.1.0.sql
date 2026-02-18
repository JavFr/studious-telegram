-- Verify fontanella:lawyers on pg
SELECT
    id,
    user_id,
    license_number,
    specialty,
    created_at,
    updated_at
FROM
    lawyers
WHERE
    FALSE;

-- UNIQUE on user_id
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conname = 'lawyers_user_id_key';
