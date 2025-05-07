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
  opts.banner = "Usage: warmup_tpch.rb [options]"

  opts.on('-s', '--scale SCALE', ['s1', 's10'], "Scale factor (s1 or s10)") do |s|
    options[:scale] = s
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!

# Determine target database
db_name = "tpch_#{options[:scale]}"

# Initialize MySQL client with persistent connection (last arg = true)
client = MySQL::Client.new(
  config['user'],
  config['port'],
  config['host'],
  db_name,
  config['path'],
  true
)

# List of TPC-H tables in dependency order
tpch_tables = %w[
  region
  nation
  supplier
  part
  partsupp
  customer
  orders
  lineitem
]

# Load each table into memory by selecting all rows
tpch_tables.each_with_index do |table, idx|
  query = "SELECT * FROM #{table};"
  header = Color.bold("Loading [#{db_name}] table #{idx+1}/#{tpch_tables.size}: #{table}")
  puts "#{header} -- Executing: #{query}"
  stdout, stderr, ok = client.run_query_get_stdout(query)
  unless ok
    puts Color.red("Error loading table #{table}: #{stderr}")
    exit 1
  end
end

puts Color.green("\nSuccessfully warmed up all tables in #{db_name}!")
