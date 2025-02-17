CREATE TABLE table_a (
  id INT PRIMARY KEY,
  name VARCHAR(50),
  value INT
);
CREATE TABLE table_b (
  id INT PRIMARY KEY,
  a_id INT,
  description VARCHAR(150),
  timestamp_col DATETIME,
  FOREIGN KEY (a_id) REFERENCES table_a(id)
);
CREATE TABLE table_c (
  id INT PRIMARY KEY,
  b_id INT,
  some_value INT,
  FOREIGN KEY (b_id) REFERENCES table_b(id)
);
