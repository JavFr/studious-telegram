-- Verify fontanella:organizations on pg
SELECT
    id,
    name,
    country,
    timezone,
    address,
    created_at,
    updated_at
FROM
    organizations
WHERE
    FALSE;
