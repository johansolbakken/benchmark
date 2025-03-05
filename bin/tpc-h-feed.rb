#!/usr/bin/env ruby

require 'optparse'
require 'open3'
require 'yaml'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

# Configuration
CONFIG  = YAML.load_file('config.yaml')['mysql']
DB_NAME = 'tpc_h'
FILES   = ['./job-schema/dss.dll', './job-schema/dss.ri']
CLIENT  = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], DB_NAME, CONFIG['path'])
DATASET_PATH = './tpc-h-dataset'

def feed_data
  # Sort tables in topological order based on schema
  schema_file = File.join("./tpc-h-schema", "dss.ddl")
  unless File.exist?(schema_file)
    puts Color.red("Schema file not found: #{schema_file}")
    exit 1
  end
  schema_sql = File.read(schema_file)
  sorted_tables = Sql_Table_Topological_Sort.sort_tables(schema_sql)
  sorted_tables.map!(&:upcase)

  # Drop existing tables before creating new ones
  sorted_tables.reverse.each do |table_name|
    CLIENT.run_query("DROP TABLE IF EXISTS #{table_name};")
  end

  # Create tables before loading data
  unless CLIENT.run_query(schema_sql)
    abort Color.red("Failed to create tables from schema file: #{schema_file}")
  end

  sorted_tables.each_with_index do |table_name, i|
    csv_file = File.expand_path(File.join(DATASET_PATH, "#{table_name}.CSV"))
    unless File.exist?(csv_file)
      abort Color.red("CSV file not found: #{csv_file}")
    end

    puts Color.bold("(#{i+1}/#{sorted_tables.count}) Running file: #{csv_file}")
    unless CLIENT.run_query("LOAD DATA LOCAL INFILE '#{csv_file}' INTO TABLE #{table_name} FIELDS TERMINATED BY ',';")
      abort Color.red("Failed to execute SQL query for file: #{csv_file}")
    end
  end

  puts Color.green("\nLoaded all CSV files into MySQL!")
rescue StandardError => e
  abort Color.red("An error occurred during feeding: #{e.message}")
end

feed_data