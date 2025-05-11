#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require_relative '../lib/mysql'
require_relative '../lib/color'

# Load MySQL config
config = YAML.load_file('config.yaml')['mysql']

# Parse command-line options
options = { scale: 's1' }
OptionParser.new do |opts|
  opts.banner = "Usage: warmup_tpcds.rb [options]"

  opts.on('-s', '--scale SCALE', ['s1','s10','s100','s1000'],
          "Scale factor (s1, s10, s100, s1000)") do |s|
    options[:scale] = s
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!

# Determine target database
db_name = "tpcds_#{options[:scale]}"

# Initialize MySQL client with persistent connection
client = MySQL::Client.new(
  config['user'],
  config['port'],
  config['host'],
  db_name,
  config['path'],
  true
)

# All TPC-DS tables defined in your schema dump
tpcds_tables = %w[
  dbgen_version
  customer_address
  customer_demographics
  date_dim
  warehouse
  ship_mode
  time_dim
  reason
  income_band
  item
  store
  call_center
  customer
  web_site
  store_returns
  household_demographics
  web_page
  promotion
  catalog_page
  inventory
  catalog_returns
  web_returns
  web_sales
  catalog_sales
  store_sales
]

# Load each table into memory by selecting all rows
tpcds_tables.each_with_index do |table, idx|
  query = "SELECT * FROM #{table};"
  header = Color.bold("Loading [#{db_name}] table #{idx+1}/#{tpcds_tables.size}: #{table}")
  puts "#{header} -- Executing: #{query}"
  stdout, stderr, ok = client.run_query_get_stdout(query)
  unless ok
    puts Color.red("Error loading table #{table}: #{stderr}")
    exit 1
  end
end

puts Color.green("\nSuccessfully warmed up all #{tpcds_tables.size} TPC-DS tables in #{db_name}!")
