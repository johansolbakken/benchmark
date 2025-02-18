#!/usr/bin/env ruby

require 'optparse'
require 'yaml'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

# Configuration
CONFIG  = YAML.load_file('config.yaml')['mysql']
DB_NAME = 'imdbload'
FILES   = ['./job-schema/schema.sql', './job-schema/fkindexes.sql']
CLIENT  = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], DB_NAME, CONFIG['path'])

# Set up the database using provided SQL files
def setup_database(force: false)
  puts 'Setting up the database...'

  if force
    puts Color.bold("Destroying database #{DB_NAME}")
    unless CLIENT.run_query_without_db("DROP DATABASE IF EXISTS #{DB_NAME};")
      abort Color.red("Failed to drop database #{DB_NAME}")
    end
  end

  puts Color.bold("Trying to create database #{DB_NAME}")
  unless CLIENT.run_query_without_db("CREATE DATABASE #{DB_NAME};")
    abort Color.red("Failed to create database #{DB_NAME}. use --force option to force delete")
  end

  FILES.each do |file|
    puts Color.bold("Running file: #{file}")
    abort Color.red("File not found: #{file}") unless File.exist?(file)
    abort Color.red("Failed to execute SQL file: #{file}") unless CLIENT.run_file(file)
  end

  puts Color.green("\nDatabase setup completed.")
rescue StandardError => e
  abort Color.red("An error occurred during setup: #{e.message}")
end

# Command-line option parsing
opts = {}
OptionParser.new do |op|
  op.banner = "Usage: #{File.basename($0)} [options]"
  op.on('--force', 'Delete database and recreate.') { opts[:force] = true }
end.parse!

setup_database(force: opts[:force]) if __FILE__ == $PROGRAM_NAME
