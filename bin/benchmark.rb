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

  return "EXPLAIN ANALYZE "      if options[:explain]
  return "EXPLAIN FORMAT=TREE "  if options[:tree]
  return "EXPLAIN FORMAT=JSON "  if options[:json]
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

  if options[:hint]
    user_hint = options[:hint]
    query_contents.sub!(/\bSELECT\b/i, "SELECT #{user_hint}")
  end

  CLIENT.run_query("#{explain_prefix}#{query_contents}")
rescue StandardError => e
  puts Color.red("An error occurred while running the query: #{e.message}")
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

    opts.on("--run FILE", "Run a specific SQL file") do |file|
      options[:query] = file
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

    opts.on("--hint HINT", "Set SQL hint") do |hint|
      options[:hint] = hint
    end

    opts.on("--database DB", "Override the database name") do |db|
      options[:database] = db
    end
  end.parse!
  options
end

##
# Main entry point
#
def run
  options = parse_options

  # Override database if specified
  CLIENT.use_database(options[:database]) if options[:database]

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
