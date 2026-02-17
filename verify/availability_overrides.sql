-- Verify fontanella:availability_overrides on pg
SELECT
    id,
    lawyer_id,
    organization_id,
    date,
    start_time,
    end_time,
    is_available,
    reason,
    created_at
FROM
    availability_overrides
WHERE
    FALSE;

-- CHECK (start_time IS NULL OR end_time IS NULL OR start_time < end_time)
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conrelid = 'availability_overrides'::REGCLASS
    AND contype = 'c';
