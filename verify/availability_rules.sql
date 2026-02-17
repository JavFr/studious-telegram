-- Verify fontanella:availability_rules on pg
SELECT
    id,
    lawyer_id,
    organization_id,
    day_of_week,
    start_time,
    end_time,
    timezone,
    created_at
FROM
    availability_rules
WHERE
    FALSE;

-- CHECK (day_of_week BETWEEN 0 AND 6)
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conname = 'availability_rules_day_of_week_check';

-- CHECK (start_time < end_time)
SELECT
    1 / COUNT(*)
FROM
    pg_constraint
WHERE
    conname = 'availability_rules_check';
