-- ===================================================================
-- TPC-H Schema Setup for Two Databases: tpch_s1 (SF=1) and tpch_s10 (SF=2)
-- ===================================================================

-- --------------------------------------------------
-- 1) Drop databases if they exist
-- --------------------------------------------------
DROP DATABASE IF EXISTS tpch_s1;
DROP DATABASE IF EXISTS tpch_s10;

-- --------------------------------------------------
-- 2) Create tpch_s1 (Scale Factor = 1)
-- --------------------------------------------------
CREATE DATABASE tpch_s1
  /*!40100 DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci */;
USE tpch_s1;

CREATE TABLE region (
  r_regionkey    INT           NOT NULL,
  r_name         CHAR(25)      NOT NULL,
  r_comment      VARCHAR(152),
  PRIMARY KEY (r_regionkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE nation (
  n_nationkey    INT           NOT NULL,
  n_name         CHAR(25)      NOT NULL,
  n_regionkey    INT           NOT NULL,
  n_comment      VARCHAR(152),
  PRIMARY KEY (n_nationkey),
  KEY idx_n_region (n_regionkey),
  CONSTRAINT fk_n_region FOREIGN KEY (n_regionkey) REFERENCES region (r_regionkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE supplier (
  s_suppkey      INT           NOT NULL,
  s_name         CHAR(25)      NOT NULL,
  s_address      VARCHAR(40)   NOT NULL,
  s_nationkey    INT           NOT NULL,
  s_phone        CHAR(15)      NOT NULL,
  s_acctbal      DECIMAL(15,2) NOT NULL,
  s_comment      VARCHAR(101)  NOT NULL,
  PRIMARY KEY (s_suppkey),
  KEY idx_s_nation (s_nationkey),
  CONSTRAINT fk_s_nation FOREIGN KEY (s_nationkey) REFERENCES nation (n_nationkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE part (
  p_partkey      INT           NOT NULL,
  p_name         VARCHAR(55)   NOT NULL,
  p_mfgr         CHAR(25)      NOT NULL,
  p_brand        CHAR(10)      NOT NULL,
  p_type         VARCHAR(25)   NOT NULL,
  p_size         INT           NOT NULL,
  p_container    CHAR(10)      NOT NULL,
  p_retailprice  DECIMAL(15,2) NOT NULL,
  p_comment      VARCHAR(23)   NOT NULL,
  PRIMARY KEY (p_partkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE partsupp (
  ps_partkey     INT           NOT NULL,
  ps_suppkey     INT           NOT NULL,
  ps_availqty    INT           NOT NULL,
  ps_supplycost  DECIMAL(15,2) NOT NULL,
  ps_comment     VARCHAR(199)  NOT NULL,
  PRIMARY KEY (ps_partkey, ps_suppkey),
  KEY idx_ps_supp (ps_suppkey),
  CONSTRAINT fk_ps_part FOREIGN KEY (ps_partkey) REFERENCES part (p_partkey),
  CONSTRAINT fk_ps_supp FOREIGN KEY (ps_suppkey) REFERENCES supplier (s_suppkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE customer (
  c_custkey      INT           NOT NULL,
  c_name         VARCHAR(25)   NOT NULL,
  c_address      VARCHAR(40)   NOT NULL,
  c_nationkey    INT           NOT NULL,
  c_phone        CHAR(15)      NOT NULL,
  c_acctbal      DECIMAL(15,2) NOT NULL,
  c_mktsegment   CHAR(10)      NOT NULL,
  c_comment      VARCHAR(117)  NOT NULL,
  PRIMARY KEY (c_custkey),
  KEY idx_c_nation (c_nationkey),
  CONSTRAINT fk_c_nation FOREIGN KEY (c_nationkey) REFERENCES nation (n_nationkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE orders (
  o_orderkey      INT           NOT NULL,
  o_custkey       INT           NOT NULL,
  o_orderstatus   CHAR(1)       NOT NULL,
  o_totalprice    DECIMAL(15,2) NOT NULL,
  o_orderdate     DATE          NOT NULL,
  o_orderpriority CHAR(15)      NOT NULL,
  o_clerk         CHAR(15)      NOT NULL,
  o_shippriority  INT           NOT NULL,
  o_comment       VARCHAR(79)   NOT NULL,
  PRIMARY KEY (o_orderkey),
  KEY idx_o_cust (o_custkey),
  CONSTRAINT fk_o_cust FOREIGN KEY (o_custkey) REFERENCES customer (c_custkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE lineitem (
  l_orderkey      INT           NOT NULL,
  l_partkey       INT           NOT NULL,
  l_suppkey       INT           NOT NULL,
  l_linenumber    INT           NOT NULL,
  l_quantity      DECIMAL(15,2) NOT NULL,
  l_extendedprice DECIMAL(15,2) NOT NULL,
  l_discount      DECIMAL(15,2) NOT NULL,
  l_tax           DECIMAL(15,2) NOT NULL,
  l_returnflag    CHAR(1)       NOT NULL,
  l_linestatus    CHAR(1)       NOT NULL,
  l_shipdate      DATE          NOT NULL,
  l_commitdate    DATE          NOT NULL,
  l_receiptdate   DATE          NOT NULL,
  l_shipinstruct  CHAR(25)      NOT NULL,
  l_shipmode      CHAR(10)      NOT NULL,
  l_comment       VARCHAR(44)   NOT NULL,
  PRIMARY KEY (l_orderkey, l_linenumber),
  KEY idx_l_part  (l_partkey),
  KEY idx_l_supp  (l_suppkey),
  KEY idx_l_order (l_orderkey),
  CONSTRAINT fk_l_order FOREIGN KEY (l_orderkey) REFERENCES orders (o_orderkey),
  CONSTRAINT fk_l_part  FOREIGN KEY (l_partkey)  REFERENCES part     (p_partkey),
  CONSTRAINT fk_l_supp  FOREIGN KEY (l_suppkey)  REFERENCES supplier (s_suppkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------
-- 3) Create tpch_s10 (Scale Factor = 2)
-- --------------------------------------------------
CREATE DATABASE tpch_s10
  /*!40100 DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci */;
USE tpch_s10;

CREATE TABLE region (
  r_regionkey    INT           NOT NULL,
  r_name         CHAR(25)      NOT NULL,
  r_comment      VARCHAR(152),
  PRIMARY KEY (r_regionkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE nation (
  n_nationkey    INT           NOT NULL,
  n_name         CHAR(25)      NOT NULL,
  n_regionkey    INT           NOT NULL,
  n_comment      VARCHAR(152),
  PRIMARY KEY (n_nationkey),
  KEY idx_n_region (n_regionkey),
  CONSTRAINT fk_n_region FOREIGN KEY (n_regionkey) REFERENCES region (r_regionkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE supplier (
  s_suppkey      INT           NOT NULL,
  s_name         CHAR(25)      NOT NULL,
  s_address      VARCHAR(40)   NOT NULL,
  s_nationkey    INT           NOT NULL,
  s_phone        CHAR(15)      NOT NULL,
  s_acctbal      DECIMAL(15,2) NOT NULL,
  s_comment      VARCHAR(101)  NOT NULL,
  PRIMARY KEY (s_suppkey),
  KEY idx_s_nation (s_nationkey),
  CONSTRAINT fk_s_nation FOREIGN KEY (s_nationkey) REFERENCES nation (n_nationkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE part (
  p_partkey      INT           NOT NULL,
  p_name         VARCHAR(55)   NOT NULL,
  p_mfgr         CHAR(25)      NOT NULL,
  p_brand        CHAR(10)      NOT NULL,
  p_type         VARCHAR(25)   NOT NULL,
  p_size         INT           NOT NULL,
  p_container    CHAR(10)      NOT NULL,
  p_retailprice  DECIMAL(15,2) NOT NULL,
  p_comment      VARCHAR(23)   NOT NULL,
  PRIMARY KEY (p_partkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE partsupp (
  ps_partkey     INT           NOT NULL,
  ps_suppkey     INT           NOT NULL,
  ps_availqty    INT           NOT NULL,
  ps_supplycost  DECIMAL(15,2) NOT NULL,
  ps_comment     VARCHAR(199)  NOT NULL,
  PRIMARY KEY (ps_partkey, ps_suppkey),
  KEY idx_ps_supp (ps_suppkey),
  CONSTRAINT fk_ps_part FOREIGN KEY (ps_partkey) REFERENCES part (p_partkey),
  CONSTRAINT fk_ps_supp FOREIGN KEY (ps_suppkey) REFERENCES supplier (s_suppkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE customer (
  c_custkey      INT           NOT NULL,
  c_name         VARCHAR(25)   NOT NULL,
  c_address      VARCHAR(40)   NOT NULL,
  c_nationkey    INT           NOT NULL,
  c_phone        CHAR(15)      NOT NULL,
  c_acctbal      DECIMAL(15,2) NOT NULL,
  c_mktsegment   CHAR(10)      NOT NULL,
  c_comment      VARCHAR(117)  NOT NULL,
  PRIMARY KEY (c_custkey),
  KEY idx_c_nation (c_nationkey),
  CONSTRAINT fk_c_nation FOREIGN KEY (c_nationkey) REFERENCES nation (n_nationkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE orders (
  o_orderkey      INT           NOT NULL,
  o_custkey       INT           NOT NULL,
  o_orderstatus   CHAR(1)       NOT NULL,
  o_totalprice    DECIMAL(15,2) NOT NULL,
  o_orderdate     DATE          NOT NULL,
  o_orderpriority CHAR(15)      NOT NULL,
  o_clerk         CHAR(15)      NOT NULL,
  o_shippriority  INT           NOT NULL,
  o_comment       VARCHAR(79)   NOT NULL,
  PRIMARY KEY (o_orderkey),
  KEY idx_o_cust (o_custkey),
  CONSTRAINT fk_o_cust FOREIGN KEY (o_custkey) REFERENCES customer (c_custkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE lineitem (
  l_orderkey      INT           NOT NULL,
  l_partkey       INT           NOT NULL,
  l_suppkey       INT           NOT NULL,
  l_linenumber    INT           NOT NULL,
  l_quantity      DECIMAL(15,2) NOT NULL,
  l_extendedprice DECIMAL(15,2) NOT NULL,
  l_discount      DECIMAL(15,2) NOT NULL,
  l_tax           DECIMAL(15,2) NOT NULL,
  l_returnflag    CHAR(1)       NOT NULL,
  l_linestatus    CHAR(1)       NOT NULL,
  l_shipdate      DATE          NOT NULL,
  l_commitdate    DATE          NOT NULL,
  l_receiptdate   DATE          NOT NULL,
  l_shipinstruct  CHAR(25)      NOT NULL,
  l_shipmode      CHAR(10)      NOT NULL,
  l_comment       VARCHAR(44)   NOT NULL,
  PRIMARY KEY (l_orderkey, l_linenumber),
  KEY idx_l_part  (l_partkey),
  KEY idx_l_supp  (l_suppkey),
  KEY idx_l_order (l_orderkey),
  CONSTRAINT fk_l_order FOREIGN KEY (l_orderkey) REFERENCES orders (o_orderkey),
  CONSTRAINT fk_l_part  FOREIGN KEY (l_partkey)  REFERENCES part     (p_partkey),
  CONSTRAINT fk_l_supp  FOREIGN KEY (l_suppkey)  REFERENCES supplier (s_suppkey)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
