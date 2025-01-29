#!/usr/bin/env ruby

require 'optparse'
require 'open3'
require 'yaml'

require_relative 'lib/sql_table_topological_sort'
require_relative 'lib/color'

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

##
# Runs a command and streams STDOUT / STDERR in real-time.
#
def run_command_stream(command)
  puts "#{Color.bold("Executing")}: #{command}"

  Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
    stdin.close

    threads = []

    # Stream STDOUT
    threads << Thread.new do
      stdout.each_line do |line|
        line.gsub("\\n", "\n").each_line { |sub_line| puts sub_line }
      end
    end

    # Stream STDERR
    threads << Thread.new do
      stderr.each_line do |line|
        line.gsub("\\n", "\n").each_line { |sub_line| warn sub_line }
      end
    end

    exit_status = wait_thr.value
    threads.each(&:join)

    unless exit_status.success?
      Color.red(puts "#{Color.red("Error")}: Command exited with status #{exit_status.exitstatus}")
      exit 1
    end
  end
end

def run_query_without_db(query)
  run_command_stream(
    "#{MYSQL_CLIENT_PATH} -u#{DB_USER} --local-infile=1 --port=#{DB_PORT} --host=#{DB_HOST} -e \"#{query}\""
  )
end

def run_query(query)
  run_command_stream(
    "#{MYSQL_CLIENT_PATH} -u#{DB_USER} --local-infile=1 --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} -e \"#{query}\""
  )
end

def run_file(file)
  run_command_stream(
    "#{MYSQL_CLIENT_PATH} -u#{DB_USER} --local-infile=1 --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{file}"
  )
end

##
# Enable local_infile in MySQL server (if needed).
#
def enable_local_infile
  run_command_stream(
    "#{MYSQL_CLIENT_PATH} -u#{DB_USER} --port=#{DB_PORT} --host=#{DB_HOST} " \
    "-e 'SET GLOBAL local_infile=1;'"
  )
end

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
   run_query_without_db(cmd)
  end

  setup_files = [
    File.join(JOB_PATH, 'schema.sql'),
    File.join(JOB_PATH, 'fkindexes.sql'),
    File.join(SQL_PATH, "experimental_setup.sql")
  ]
  setup_files.each do |file|
    run_file(file)
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
  explain_prefix = build_explain_prefix(options)
  query_contents = File.read(query_file)

  run_query("#{explain_prefix}#{query_contents}")
rescue StandardError => e
  puts Color.red("An error occurred while running the query: #{e.message}")
  exit 1
end

##
# Subcommand: Feed all CSV data (in topological order) into DB
#
def feed_data
  enable_local_infile

  # Sort tables in topological order based on schema
  schema_sql = File.read(File.join(JOB_PATH, "schema.sql"))
  sorted_tables = Sql_Table_Topological_Sort.sort_tables(schema_sql)

  sorted_tables.each do |table_name|
    csv_file = File.expand_path(File.join(DATASET_PATH, "#{table_name}.csv"))
    run_query("LOAD DATA LOCAL INFILE '#{csv_file}' INTO TABLE #{table_name} FIELDS TERMINATED BY ',';")
  end

  run_file(File.join(SQL_PATH, "analyze_tables.sql"))

  puts Color.green("\nLoaded all CSV files into MySQL!")
rescue StandardError => e
  puts Color.red("An error occurred during feeding: #{e.message}")
  exit 1
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
  else
    puts Color.red("No valid option provided.")
    puts "Use #{Color.bold("--setup")} to create schema, #{Color.bold("--run FILE")} to run a file, or #{Color.bold("--feed")} to load CSV data."
  end
end

# Execute if called directly
run if __FILE__ == $PROGRAM_NAME
