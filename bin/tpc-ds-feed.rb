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

# TPC-DS table load order (basic recommended order; adjust if needed)
TABLES = %w[
  call_center catalog_page catalog_returns catalog_sales customer
  customer_address customer_demographics date_dim household_demographics
  income_band inventory item promotion reason ship_mode store
  store_returns store_sales time_dim warehouse web_page
  web_returns web_sales web_site
]

# Main loading function
def feed_data(client, dataset_path)
  TABLES.each_with_index do |table, index|
    tbl_file = File.expand_path(File.join(dataset_path, "#{table}.tbl"))
    unless File.exist?(tbl_file)
      abort Color.red(".dat file not found: #{tbl_file}")
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
  db_name      = "tpcds_#{scale}"
  dataset_path = "./tpc-ds-#{scale}-dataset"

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
