#!/usr/bin/env ruby

require 'optparse'
require 'open3'
require 'yaml'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

##
# Configuration
#
CONFIG = YAML.load_file('config.yaml')
MYSQL_CONFIG = CONFIG['mysql']
MYSQL_CLIENT_PATH = MYSQL_CONFIG['path']
DB_USER  = MYSQL_CONFIG['user']
DB_PORT  = MYSQL_CONFIG['port']
DB_HOST  = MYSQL_CONFIG['host']
DB_NAME  = MYSQL_CONFIG['name']
JOB_PATH = './job'
SQL_PATH = './sql'
DATASET_PATH = './dataset'

CLIENT = MySQL::Client.new(DB_USER, DB_PORT, DB_HOST, DB_NAME, MYSQL_CLIENT_PATH)

##
# Subcommand: Setup database with schema + foreign keys
#
def setup_database
  puts "Setting up the database..."

  commands = [
    "SET GLOBAL local_infile=1;",
    "DROP DATABASE IF EXISTS #{DB_NAME};",
    "CREATE DATABASE #{DB_NAME};",
  ]
  commands.each do |cmd|
    CLIENT.run_query_without_db(cmd)
  end

  setup_files = [
    File.join(JOB_PATH, 'schema.sql'),
    File.join(JOB_PATH, 'fkindexes.sql'),
    File.join(SQL_PATH, "experimental_setup.sql")
  ]
  setup_files.each do |file|
    unless File.exist?(file)
      puts Color.red("File not found: #{file}")
      exit 1
    end
    CLIENT.run_file(file)
  end

  puts Color.green("\nDatabase setup completed.")
rescue StandardError => e
  puts Color.red("An error occurred during setup: #{e.message}")
  exit 1
end

##
# Determine the EXPLAIN mode (if any)
#
def build_explain_prefix(options)
  # Only allow one of --analyze, --tree, --json
  explain_options = [:explain, :tree, :json]
  active_explains = explain_options.select { |opt| options[opt] }

  if active_explains.size > 1
    puts Color.red("Error: cannot use more than one EXPLAIN option at a time.")
    exit 1
  end

  return "" if active_explains.empty?

  return "EXPLAIN ANALYZE "    if options[:explain]
  return "EXPLAIN FORMAT=TREE " if options[:tree]
  return "EXPLAIN FORMAT=JSON " if options[:json]
  ""
end

##
# Subcommand: Run query from file (with optional EXPLAIN)
#
def run_query_file(query_file, options)
  unless File.exist?(query_file)
    puts Color.red("Query file not found: #{query_file}")
    exit 1
  end
  explain_prefix = build_explain_prefix(options)
  query_contents = File.read(query_file)
  CLIENT.run_query("#{explain_prefix}#{query_contents}")
rescue StandardError => e
  puts Color.red("An error occurred while running the query: #{e.message}")
  exit 1
end

##
# Subcommand: Feed all CSV data (in topological order) into DB
#
def feed_data
  # Sort tables in topological order based on schema
  schema_file = File.join(JOB_PATH, "schema.sql")
  unless File.exist?(schema_file)
    puts Color.red("Schema file not found: #{schema_file}")
    exit 1
  end
  schema_sql = File.read(schema_file)
  sorted_tables = Sql_Table_Topological_Sort.sort_tables(schema_sql)

  sorted_tables.each do |table_name|
    csv_file = File.expand_path(File.join(DATASET_PATH, "#{table_name}.csv"))
    unless File.exist?(csv_file)
      puts Color.red("CSV file not found: #{csv_file}")
      exit 1
    end
    CLIENT.run_query("LOAD DATA LOCAL INFILE '#{csv_file}' INTO TABLE #{table_name} FIELDS TERMINATED BY ',';")
  end

  CLIENT.run_file(File.join(SQL_PATH, "experimental_setup.sql"))
  puts Color.green("\nLoaded all CSV files into MySQL!")
rescue StandardError => e
  puts Color.red("An error occurred during feeding: #{e.message}")
  exit 1
end

##
# Subcommand: Prepare MySQL environment (analyze tables, etc.)
#
def prepare_mysql
  CLIENT.run_file(File.join(SQL_PATH, "experimental_setup.sql"))
  CLIENT.run_file(File.join(SQL_PATH, "analyze_tables.sql"))
  puts Color.green("\nPrepared MySQL environment")
end

##
# Parse command line options
#
def parse_options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: run_queries.rb [options]"

    opts.on("--setup", "Setup the database with schema and foreign key indexes") do
      options[:setup] = true
    end

    opts.on("--run FILE", "Run a specific SQL file") do |file|
      options[:query] = file
    end

    opts.on("--feed", "Feed all CSV files in the downloads folder into the database") do
      options[:feed] = true
    end

    opts.on("--prepare-mysql", "Sets costs and hypergraph optimizer use and analyzes tables") do
      options[:prepare] = true
    end

    opts.on("--analyze", "Use EXPLAIN ANALYZE") do
      options[:explain] = true
    end

    opts.on("--tree", "Use EXPLAIN FORMAT=TREE") do
      options[:tree] = true
    end

    opts.on("--json", "Use EXPLAIN FORMAT=JSON") do
      options[:json] = true
    end
  end.parse!
  options
end

##
# Main entry point
#
def run
  options = parse_options

  if options[:setup]
    setup_database
  elsif options[:query]
    run_query_file(options[:query], options)
  elsif options[:feed]
    feed_data
  elsif options[:prepare]
    prepare_mysql
  else
    puts Color.red("No valid option provided.")
    puts "Use #{Color.bold('--setup')} to create schema, #{Color.bold('--run FILE')} to run a file, or #{Color.bold('--feed')} to load CSV data."
  end
end

# Execute if called directly
run if __FILE__ == $PROGRAM_NAME
