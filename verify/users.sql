-- Verify fontanella:users on pg
SELECT
    id,
    email,
    password_hash,
    auth_provider,
    auth_provider_id,
    created_at,
    updated_at
FROM
    users
WHERE
    FALSE;
