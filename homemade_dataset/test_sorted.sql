USE test_sort_hashjoin_db;

SET @prev_id = NULL;

SELECT COUNT(*) AS not_sorted_count
FROM (
  SELECT 
    CASE 
      WHEN @prev_id IS NOT NULL AND sub.table_a_id < @prev_id THEN 'Not Sorted'
      ELSE 'Sorted'
    END AS sorted_status,
    (@prev_id := sub.table_a_id) AS dummy
  FROM (
    -- The query being tested: sorted on a.id (aliased as table_a_id)
    SELECT 
      a.id AS table_a_id,
      a.name,
      a.value,
      b.id AS table_b_id,
      b.description,
      b.timestamp_col
    FROM table_a AS a
    JOIN table_b AS b
      ON b.a_id = a.id
    ORDER BY a.id ASC
  ) AS sub
) AS check_sorted
WHERE sorted_status = 'Not Sorted';

