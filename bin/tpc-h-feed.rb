#!/usr/bin/env ruby

require 'optparse'
require 'open3'
require 'yaml'

require_relative '../lib/color'
require_relative '../lib/mysql'

# Load configuration
CONFIG = YAML.load_file('config.yaml')['mysql']

# Define scales and corresponding databases and dataset directories
SCALES = ['s1', 's10']

# Table load order to satisfy foreign key dependencies
TABLES = %w[
  region
  nation
  supplier
  part
  partsupp
  customer
  orders
  lineitem
]

# Main loading function
def feed_data(client, dataset_path)
  TABLES.each_with_index do |table, index|
    tbl_file = File.expand_path(File.join(dataset_path, "#{table}.tbl"))
    unless File.exist?(tbl_file)
      abort Color.red(".tbl file not found: #{tbl_file}")
    end

    puts Color.bold("(#{index + 1}/#{TABLES.size}) Loading table: #{table} from #{tbl_file}")
    load_sql = <<~SQL
      LOAD DATA LOCAL INFILE '#{tbl_file}' \
      INTO TABLE #{table} \
      FIELDS TERMINATED BY '|' \
      LINES TERMINATED BY '|\\n';
    SQL

    unless client.run_query(load_sql)
      abort Color.red("Failed to load data for table: #{table}")
    end
  end

  puts Color.green("\nAll tables loaded for database #{client.db_name}!")
rescue StandardError => e
  abort Color.red("Error during data load: #{e.message}")
end

# Iterate through each scale and load data
SCALES.each do |scale|
  db_name      = "tpch_#{scale}"
  dataset_path = "./tpc-h-#{scale}-dataset"

  puts Color.blue("\n==> Starting load for Scale Factor #{scale} (DB: #{db_name}) <==")
  unless Dir.exist?(dataset_path)
    abort Color.red("Dataset directory not found: #{dataset_path}")
  end

  client = MySQL::Client.new(
    CONFIG['user'],
    CONFIG['port'],
    CONFIG['host'],
    db_name,
    CONFIG['path']
  )

  feed_data(client, dataset_path)
end
