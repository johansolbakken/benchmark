-- Based on: 'Using Re-Optimization in MySQL to Improve Query Plans'
-- NTNU Master Thesis, 2024 (Elton & Rosendahl) - https://hdl.handle.net/11250/3153611

UPDATE mysql.engine_cost SET cost_value = 0.25 WHERE cost_name = 'io_block_read_cost';
UPDATE mysql.engine_cost SET cost_value = 0.25 WHERE cost_name = 'memory_block_read_cost';

FLUSH OPTIMIZER_COSTS;

SET PERSIST innodb_stats_persistent = 1;
SET PERSIST innodb_stats_auto_recalc = 0;
SET PERSIST innodb_buffer_pool_size = 17179869184; -- 16GB
SET PERSIST join_buffer_size = 1048576; -- 1MB

SET GLOBAL optimizer_switch = 'hypergraph_optimizer=on';
