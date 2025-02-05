
SET @prev_id = NULL;

SELECT 
  current_id,
  previous_id,
  CASE 
    WHEN previous_id IS NOT NULL AND current_id < previous_id THEN 'Not Sorted'
    ELSE 'Sorted'
  END AS sorted_status
FROM (
  SELECT 
    table_a.id AS current_id,
    @prev_id AS previous_id,
    (@prev_id := table_a.id) AS dummy
  FROM table_b
  JOIN table_a ON table_b.a_id = table_a.id
  ORDER BY table_a.id
) AS sub;
