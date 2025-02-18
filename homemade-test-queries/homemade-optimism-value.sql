USE test_sort_hashjoin_db;

EXPLAIN FORMAT=tree
SELECT /*+ SET_OPTIMISM_LEVEL(0.42) */
  a.id AS table_a_id,
  a.name,
  a.value,
  b.id AS table_b_id,
  b.description,
  b.timestamp_col
FROM table_a AS a
JOIN table_b AS b
  ON b.a_id = a.id
ORDER BY b.a_id ASC;
