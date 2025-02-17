#!/usr/bin/env ruby
# Usage: ruby bin/homemade-generate.rb [num_rows_table_a] [num_rows_table_b] [output_directory]
#
# Example:
#   ruby generate_sort_hashjoin_dataset.rb 10000 50000 ./output
#
# This script generates three CSV files:
#  1. table_a.csv (id, name, value)
#  2. table_b.csv (id, a_id, description, timestamp_col)
#  3. table_c.csv (id, b_id, some_value)
#
# It populates the files with data such that some columns in table_b and table_c are
# dependent on the data in table_a and table_b, respectively.

require 'csv'
require 'securerandom'
require 'time'
require 'fileutils'

# Command-line Arguments
num_rows_a = (ARGV[0] || 10).to_i
num_rows_b = (ARGV[1] || 10).to_i
output_dir = ARGV[2] || 'homemade-dataset'

# Ensure the output directory exists.
FileUtils.mkdir_p(output_dir)

# Seed the Ruby pseudorandom number generator.
srand(42)

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

puts "Generating data and writing CSV files..."

##
# Stage 1: Generate Data for table_a
##
table_a_records = []  # Each element will be a hash with keys: :id, :name, and :value.
ids_a = (1..(num_rows_a * 10)).to_a.sample(num_rows_a)

ids_a.each do |id|
  name  = random_string(10)
  value = random_int(1, 1_000_000)
  table_a_records << { id: id, name: name, value: value }
end

# Write table_a data to CSV.
CSV.open(File.join(output_dir, "table_a.csv"), "w") do |csv|
  csv << ["id", "name", "value"]
  table_a_records.each do |row|
    csv << [row[:id], row[:name], row[:value]]
  end
end
puts "Wrote #{num_rows_a} rows to table_a.csv."

##
# Stage 2: Generate Data for table_b
##
table_b_records = []  # Each element will be a hash with keys: :id, :a_id, :description, :timestamp_col.
ids_b = (1..(num_rows_b * 10)).to_a.sample(num_rows_b)

ids_b.each do |id|
  # Pick a random table_a record.
  table_a_row = table_a_records.sample
  a_id        = table_a_row[:id]
  # Create a description that depends on table_a's name and value.
  description = "For #{table_a_row[:name]}(#{table_a_row[:value]}): " + random_string(10)
  timestamp   = random_timestamp(2000, 2025)
  table_b_records << { id: id, a_id: a_id, description: description, timestamp_col: timestamp }
end

# Write table_b data to CSV.
CSV.open(File.join(output_dir, "table_b.csv"), "w") do |csv|
  csv << ["id", "a_id", "description", "timestamp_col"]
  table_b_records.each do |row|
    csv << [row[:id], row[:a_id], row[:description], row[:timestamp_col]]
  end
end
puts "Wrote #{num_rows_b} rows to table_b.csv."

##
# Stage 3: Generate Data for table_c
##
# For table_c, we generate as many rows as table_b.
ids_c = (1..(num_rows_b * 2)).to_a.sample(num_rows_b)
table_c_records = []

ids_c.each do |id|
  # Associate each table_c row with a random table_b row.
  table_b_row = table_b_records.sample
  b_id        = table_b_row[:id]
  # Make some_value be b_id plus a small random offset.
  some_value  = b_id + random_int(0, 100)
  table_c_records << { id: id, b_id: b_id, some_value: some_value }
end

# Write table_c data to CSV.
CSV.open(File.join(output_dir, "table_c.csv"), "w") do |csv|
  csv << ["id", "b_id", "some_value"]
  table_c_records.each do |row|
    csv << [row[:id], row[:b_id], row[:some_value]]
  end
end
puts "Wrote #{table_c_records.size} rows to table_c.csv."

puts "Finished populating dataset!"
puts "  - table_a: #{num_rows_a} rows"
puts "  - table_b: #{num_rows_b} rows"
puts "  - table_c: #{table_c_records.size} rows"
