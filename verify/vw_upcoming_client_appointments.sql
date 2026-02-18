-- Verify fontanella:vw_upcoming_client_appointments on pg
SELECT
    1 / COUNT(*)
FROM
    pg_views
WHERE
    viewname = 'vw_upcoming_client_appointments';
