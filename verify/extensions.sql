-- Verify fontanella:extensions on pg
SELECT
    1 / COUNT(*)
FROM
    pg_extension
WHERE
    extname = 'btree_gist';
