-- Verify fontanella:organization_members on pg
SELECT
    id,
    user_id,
    organization_id,
    ROLE,
    created_at
FROM
    organization_members
WHERE
    FALSE;

-- UNIQUE (user_id, organization_id)
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conname = 'organization_members_user_id_organization_id_key';
