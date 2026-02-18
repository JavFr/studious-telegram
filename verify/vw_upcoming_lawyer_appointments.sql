-- Verify fontanella:vw_upcoming_lawyer_appointments on pg
SELECT
    1 / COUNT(*)
FROM
    pg_views
WHERE
    viewname = 'vw_upcoming_lawyer_appointments';
