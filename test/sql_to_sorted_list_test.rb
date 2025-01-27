#!/usr/bin/env ruby

require_relative '../lib/sql_table_topological_sort'

class Test
  attr_accessor :sql_statement, :expected_sorted_output

  def initialize(sql_statement, expected_sorted_output)
    @sql_statement = sql_statement
    @expected_sorted_output = expected_sorted_output
  end

  def display_test
    puts "SQL Statement: #{@sql_statement}"
    puts "Expected Sorted Output: #{@expected_sorted_output.inspect}"
  end

  def run_test(actual_output)
    sorted_actual = actual_output.sort
    if sorted_actual == @expected_sorted_output
      puts "Test Passed!"
    else
      puts "Test Failed."
      puts "Actual Output: #{sorted_actual.inspect}"
      puts "Expected Output: #{@expected_sorted_output.inspect}"
    end
  end
end

# Test cases
tests = []

# Test case 1: Simple dependency
tests << Test.new(<<-SQL, ['aka_name', 'aka_title', 'cast_info'])
CREATE TABLE aka_name (
    id integer NOT NULL PRIMARY KEY
);

CREATE TABLE aka_title (
    id integer NOT NULL PRIMARY KEY,
    kind_id integer NOT NULL
);

CREATE TABLE cast_info (
    id integer NOT NULL PRIMARY KEY,
    person_id integer NOT NULL REFERENCES aka_name(id),
    movie_id integer NOT NULL REFERENCES aka_title(id)
);
SQL

# Test case 2: No dependencies
tests << Test.new(<<-SQL, ['table_a', 'table_b', 'table_c'])
CREATE TABLE table_a (
    id integer NOT NULL PRIMARY KEY
);

CREATE TABLE table_b (
    id integer NOT NULL PRIMARY KEY
);

CREATE TABLE table_c (
    id integer NOT NULL PRIMARY KEY
);
SQL

# Test case 3: Multiple dependencies
tests << Test.new(<<-SQL, ['table_x', 'table_y', 'table_z'])
CREATE TABLE table_x (
    id integer NOT NULL PRIMARY KEY
);

CREATE TABLE table_y (
    id integer NOT NULL PRIMARY KEY,
    x_id integer NOT NULL REFERENCES table_x(id)
);

CREATE TABLE table_z (
    id integer NOT NULL PRIMARY KEY,
    y_id integer NOT NULL REFERENCES table_y(id)
);
SQL

# Test case 5: Standalone table
tests << Test.new(<<-SQL, ['standalone_table'])
CREATE TABLE standalone_table (
    id integer NOT NULL PRIMARY KEY
);
SQL

# Test case 6: Complex dependency graph
tests << Test.new(<<-SQL, ['table_1', 'table_2', 'table_3', 'table_4'])
CREATE TABLE table_1 (
    id integer NOT NULL PRIMARY KEY
);

CREATE TABLE table_2 (
    id integer NOT NULL PRIMARY KEY,
    table_1_id integer NOT NULL REFERENCES table_1(id)
);

CREATE TABLE table_3 (
    id integer NOT NULL PRIMARY KEY,
    table_2_id integer NOT NULL REFERENCES table_2(id)
);

CREATE TABLE table_4 (
    id integer NOT NULL PRIMARY KEY,
    table_1_id integer NOT NULL REFERENCES table_1(id),
    table_3_id integer NOT NULL REFERENCES table_3(id)
);
SQL

# Run all tests
tests.each_with_index do |test, index|
  puts "Running Test #{index + 1}"
  sorted_tables = begin
    Sql_Table_Topological_Sort.sort_tables(test.sql_statement)
  rescue => e
    puts "Error: #{e.message}"
    []
  end
  test.run_test(sorted_tables)
  puts
end
