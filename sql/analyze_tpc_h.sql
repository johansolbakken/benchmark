-- analyze_tpch.sql

-- Analyze all TPC-H tables in tpch_s1
USE tpch_s1;

ANALYZE TABLE region;
ANALYZE TABLE nation;
ANALYZE TABLE supplier;
ANALYZE TABLE part;
ANALYZE TABLE partsupp;
ANALYZE TABLE customer;
ANALYZE TABLE orders;
ANALYZE TABLE lineitem;

-- Analyze all TPC-H tables in tpch_s10
USE tpch_s10;

ANALYZE TABLE region;
ANALYZE TABLE nation;
ANALYZE TABLE supplier;
ANALYZE TABLE part;
ANALYZE TABLE partsupp;
ANALYZE TABLE customer;
ANALYZE TABLE orders;
ANALYZE TABLE lineitem;
