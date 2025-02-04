
#!/usr/bin/env ruby

# Usage: ruby generate_sort_hashjoin_dataset.rb [num_rows_table_a] [num_rows_table_b]
#
# Example:
#   ruby generate_sort_hashjoin_dataset.rb 10000 50000
# This will create table_a.sql with 10,000 INSERTs and table_b.sql with 50,000 INSERTs.
#
# Description:
#  - Creates SQL files for two tables in a database called test_sort_hashjoin_db:
#    1) table_a (id, name, value)
#    2) table_b (id, a_id, description, timestamp_col)
#  - table_b references table_a.id to allow for hash join tests on a_id vs id.
#  - Contains random data to test sorting (e.g., on name/value) and hash join performance.

require 'securerandom'
require 'time'

DATABASE_NAME = "test_sort_hashjoin_db"

# Default row counts if not specified via command-line
num_rows_a = (ARGV[0] || 10).to_i
num_rows_b = (ARGV[1] || 10).to_i

# Utility function to generate a random string of specified length
def random_string(length = 10)
  SecureRandom.alphanumeric(length)
end

# Utility function to generate a random integer within a given range
def random_int(min = 1, max = 1_000_000)
  rand(min..max)
end

# Utility function to generate a random timestamp in a range
def random_timestamp(start_year = 2000, end_year = 2025)
  # Create random time between start_year-01-01 and end_year-12-31
  start_time = Time.local(start_year, 1, 1).to_i
  end_time   = Time.local(end_year, 12, 31).to_i
  random_time = Time.at(rand(start_time..end_time))
  # Convert to a SQL-friendly datetime string
  random_time.strftime('%Y-%m-%d %H:%M:%S')
end

#
# Generate table_a.sql
#
File.open('table_a.sql', 'w') do |f|
  f.puts "-- Dataset Name: #{DATABASE_NAME}"
  f.puts "-- This file contains the CREATE and INSERT statements for table_a."
  f.puts "-- table_a is meant to test sorting on name and value columns."
  f.puts "-- Additionally, it serves as a parent table for table_b for joins."
  f.puts

  # Database creation statements (modify for your SQL dialect if needed)
  f.puts "DROP DATABASE IF EXISTS #{DATABASE_NAME};"
  f.puts "CREATE DATABASE #{DATABASE_NAME};"
  f.puts "USE #{DATABASE_NAME};"
  f.puts

  f.puts "DROP TABLE IF EXISTS table_a;"
  f.puts "CREATE TABLE table_a ("
  f.puts "  id INT PRIMARY KEY,"
  f.puts "  name VARCHAR(50),"
  f.puts "  value INT"
  f.puts ");"
  f.puts

  (1..num_rows_a).each do |i|
    name  = random_string(10)
    value = random_int(1, 1_000_000)
    f.puts "INSERT INTO table_a (id, name, value) VALUES (#{i}, '#{name}', #{value});"
  end
end

#
# Generate table_b.sql
#
File.open('table_b.sql', 'w') do |f|
  f.puts "-- Dataset Name: #{DATABASE_NAME}"
  f.puts "-- This file contains the CREATE and INSERT statements for table_b."
  f.puts "-- table_b references table_a (via a_id) for testing hash joins."
  f.puts "-- Also has a datetime column for more varied data."
  f.puts

  # We assume the database already exists and was created in table_a.sql,
  # so we only 'USE' it here:
  f.puts "USE #{DATABASE_NAME};"
  f.puts

  f.puts "DROP TABLE IF EXISTS table_b;"
  f.puts "CREATE TABLE table_b ("
  f.puts "  id INT PRIMARY KEY,"
  f.puts "  a_id INT,"
  f.puts "  description VARCHAR(100),"
  f.puts "  timestamp_col DATETIME,"
  f.puts "  FOREIGN KEY (a_id) REFERENCES table_a(id)"
  f.puts ");"
  f.puts

  (1..num_rows_b).each do |i|
    a_id        = rand(1..num_rows_a)
    description = random_string(20)
    timestamp   = random_timestamp(2000, 2025)
    f.puts "INSERT INTO table_b (id, a_id, description, timestamp_col)"
    f.puts "  VALUES (#{i}, #{a_id}, '#{description}', '#{timestamp}');"
  end
end

puts "Finished generating table_a.sql and table_b.sql!"
puts "  - table_a: #{num_rows_a} rows"
puts "  - table_b: #{num_rows_b} rows"
puts "Dataset name: #{DATABASE_NAME}"

