#!/usr/bin/env ruby
#
# Usage: ruby generate_sort_hashjoin_dataset.rb [num_rows_table_a] [num_rows_table_b]
#
# Example:
#   ruby generate_sort_hashjoin_dataset.rb 10000 50000
#
# This script creates three tables in a database called test_sort_hashjoin_db:
#  1. table_a (id, name, value)
#  2. table_b (id, a_id, description, timestamp_col)
#  3. table_c (id, b_id, some_value)
#
# It then populates the tables with data such that some columns in table_b and table_c
# are dependent on the data in table_a and table_b, respectively.
# Instead of writing SQL files, it runs the SQL queries directly using MySQL::Client.

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

# Seed the Ruby pseudorandom number generator
srand(42)

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

# Create tables. We combine table_a, table_b, and table_c creation into one SQL statement.
setup_sql = <<-SQL
USE #{DB_NAME};
DROP TABLE IF EXISTS table_c;
DROP TABLE IF EXISTS table_b;
DROP TABLE IF EXISTS table_a;
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
SQL

CLIENT.run_query(setup_sql)
puts Color.green("Database and tables setup completed.")

##
# Stage 2: Insert Data into Tables
##

puts Color.blue("Inserting data into tables...")

# --- Insert Data into table_a ---
# We'll save table_a records in an array to create a dependency for table_b.
insert_sql_a = "USE #{DB_NAME};\n"
table_a_records = []  # Each element will be a hash with keys: :id, :name, and :value.
# Generate unique random IDs for table_a (sampled from a larger range to reduce duplicates).
ids_a = (1..(num_rows_a * 10)).to_a.sample(num_rows_a)

ids_a.each do |id|
  name  = random_string(10)
  value = random_int(1, 1_000_000)
  table_a_records << { id: id, name: name, value: value }
  insert_sql_a << "INSERT INTO table_a (id, name, value) VALUES (#{id}, '#{name}', #{value});\n"
end

# Execute all INSERTs for table_a as one stage.
CLIENT.run_query(insert_sql_a)
puts Color.green("Inserted #{num_rows_a} rows into table_a.")

# --- Insert Data into table_b ---
# We'll build stronger dependency by using table_a's data to construct the description.
insert_sql_b = "USE #{DB_NAME};\n"
# Generate unique random IDs for table_b.
ids_b = (1..(num_rows_b * 10)).to_a.sample(num_rows_b)

# Save table_b records if needed for table_c dependency.
table_b_records = []  # Each element will be a hash with keys: :id, :a_id, :timestamp

ids_b.each do |id|
  # Pick a table_a record at random
  table_a_row = table_a_records.sample
  a_id        = table_a_row[:id]
  # Create a description that depends on table_a's name and value.
  description = "For #{table_a_row[:name]}(#{table_a_row[:value]}): " + random_string(10)
  timestamp   = random_timestamp(2000, 2025)
  table_b_records << { id: id, a_id: a_id, timestamp: timestamp }
  insert_sql_b << "INSERT INTO table_b (id, a_id, description, timestamp_col) VALUES (#{id}, #{a_id}, '#{description}', '#{timestamp}');\n"
end

# Execute all INSERTs for table_b as one stage.
CLIENT.run_query(insert_sql_b)
puts Color.green("Inserted #{num_rows_b} rows into table_b.")

# --- Insert Data into table_c ---
# Here, we'll make some_value depend on the selected table_b record's id.
insert_sql_c = "USE #{DB_NAME};\n"
# Generate unique random IDs for table_c.
ids_c = (1..(num_rows_b * 2)).to_a.sample(num_rows_b)

ids_c.each do |id|
  # Associate table_c row with a table_b row.
  table_b_row = table_b_records.sample
  b_id        = table_b_row[:id]
  # Make some_value be b_id plus a small random offset.
  some_value  = b_id + random_int(0, 100)
  insert_sql_c << "INSERT INTO table_c (id, b_id, some_value) VALUES (#{id}, #{b_id}, #{some_value});\n"
end

# Execute all INSERTs for table_c
CLIENT.run_query(insert_sql_c)
puts Color.green("Inserted #{num_rows_b} rows into table_c.")

puts Color.green("Finished populating dataset!")
puts Color.green("  - table_a: #{num_rows_a} rows")
puts Color.green("  - table_b: #{num_rows_b} rows")
puts Color.green("Dataset name: #{DB_NAME}")
