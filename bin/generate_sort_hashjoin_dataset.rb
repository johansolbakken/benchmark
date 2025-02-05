#!/usr/bin/env ruby
#
# Usage: ruby generate_sort_hashjoin_dataset.rb [num_rows_table_a] [num_rows_table_b]
#
# Example:
#   ruby generate_sort_hashjoin_dataset.rb 10000 50000
#
# This script creates two tables in a database called test_sort_hashjoin_db:
#  1. table_a (id, name, value)
#  2. table_b (id, a_id, description, timestamp_col)
#
# It then populates table_a and table_b with random data.
# Instead of writing SQL files, it runs the SQL queries directly using MySQL::Client.
#

require 'securerandom'
require 'time'
require 'yaml'
require 'optparse'

require_relative '../lib/mysql'
require_relative '../lib/color'

##
# Load Configuration
#
# Adjust the path if your config.yaml is in the project root.
CONFIG = YAML.load_file(File.expand_path('../config.yaml', __dir__))
MYSQL_CONFIG      = CONFIG['mysql']
MYSQL_CLIENT_PATH = MYSQL_CONFIG['path']
DB_USER           = MYSQL_CONFIG['user']
DB_PORT           = MYSQL_CONFIG['port']
DB_HOST           = MYSQL_CONFIG['host']
DB_NAME           = 'test_sort_hashjoin_db'

# Initialize the MySQL client using the provided configuration.
CLIENT = MySQL::Client.new(DB_USER, DB_PORT, DB_HOST, DB_NAME, MYSQL_CLIENT_PATH)

# Default row counts if not specified via command-line arguments.
num_rows_a = (ARGV[0] || 10).to_i
num_rows_b = (ARGV[1] || 10).to_i

##
# Utility Functions
#
def random_string(length = 10)
  SecureRandom.alphanumeric(length)
end

def random_int(min = 1, max = 1_000_000)
  rand(min..max)
end

def random_timestamp(start_year = 2000, end_year = 2025)
  start_time = Time.local(start_year, 1, 1).to_i
  end_time   = Time.local(end_year, 12, 31).to_i
  random_time = Time.at(rand(start_time..end_time))
  random_time.strftime('%Y-%m-%d %H:%M:%S')
end

##
# Stage 1: Setup Database and Tables
##

puts Color.blue("Setting up database and tables...")

# Drop and create the database. These commands need no default database, so use run_query_without_db.
CLIENT.run_query_without_db("DROP DATABASE IF EXISTS #{DB_NAME};")
CLIENT.run_query_without_db("CREATE DATABASE #{DB_NAME};")

# Create tables. We combine table_a and table_b creation into one SQL statement.
setup_sql = <<-SQL
USE #{DB_NAME};
DROP TABLE IF EXISTS table_a;
CREATE TABLE table_a (
  id INT PRIMARY KEY,
  name VARCHAR(50),
  value INT
);
DROP TABLE IF EXISTS table_b;
CREATE TABLE table_b (
  id INT PRIMARY KEY,
  a_id INT,
  description VARCHAR(100),
  timestamp_col DATETIME,
  FOREIGN KEY (a_id) REFERENCES table_a(id)
);
SQL

CLIENT.run_query(setup_sql)
puts Color.green("Database and tables setup completed.")

##
# Stage 2: Insert Data into Tables
##

puts Color.blue("Inserting data into tables...")

# Build the INSERT statements for table_a.
insert_sql_a = "USE #{DB_NAME};\n"
# Generate unique random IDs for table_a (sampled from a larger range to reduce duplicates).
ids_a = (1..(num_rows_a * 10)).to_a.sample(num_rows_a)

ids_a.each do |id|
  name  = random_string(10)
  value = random_int(1, 1_000_000)
  insert_sql_a << "INSERT INTO table_a (id, name, value) VALUES (#{id}, '#{name}', #{value});\n"
end

# Execute all INSERTs for table_a as one stage.
CLIENT.run_query(insert_sql_a)
puts Color.green("Inserted #{num_rows_a} rows into table_a.")

# Build the INSERT statements for table_b.
insert_sql_b = "USE #{DB_NAME};\n"
# Generate unique random IDs for table_b.
ids_b = (1..(num_rows_b * 10)).to_a.sample(num_rows_b)

ids_b.each do |id|
  a_id        = ids_a.sample
  description = random_string(20)
  timestamp   = random_timestamp(2000, 2025)
  insert_sql_b << "INSERT INTO table_b (id, a_id, description, timestamp_col) VALUES (#{id}, #{a_id}, '#{description}', '#{timestamp}');\n"
end

# Execute all INSERTs for table_b as one stage.
CLIENT.run_query(insert_sql_b)
puts Color.green("Inserted #{num_rows_b} rows into table_b.")

puts Color.green("Finished populating dataset!")
puts Color.green("  - table_a: #{num_rows_a} rows")
puts Color.green("  - table_b: #{num_rows_b} rows")
puts Color.green("Dataset name: #{DB_NAME}")
