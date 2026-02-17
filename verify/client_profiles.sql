-- Verify fontanella:client_profiles on pg
SELECT
    id,
    user_id,
    organization_id,
    first_name,
    last_name,
    phone,
    notes,
    created_at,
    updated_at
FROM
    client_profiles
WHERE
    FALSE;

-- UNIQUE (user_id, organization_id)
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conname = 'client_profiles_user_id_organization_id_key';
