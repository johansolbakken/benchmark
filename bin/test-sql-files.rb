#!/usr/bin/env ruby

require 'optparse'
require 'yaml'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

# Parse command-line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} --folder FOLDER --database DB_NAME"

  opts.on("-fFOLDER", "--folder=FOLDER", "Folder containing SQL files") do |folder|
    options[:folder] = folder
  end

  opts.on("-dDB", "--database=DB", "Database name") do |db|
    options[:database] = db
  end

  opts.on("-h", "--help", "Displays Help") do
    puts opts
    exit
  end
end.parse!

# Validate required options
if options[:folder].nil? || options[:database].nil?
  puts Color.red("Error: Both --folder and --database options are required.")
  exit 1
end

DB_NAME = options[:database]

# Load MySQL configuration from YAML file
CONFIG = YAML.load_file('config.yaml')['mysql']

# Get all SQL files from the provided folder
sql_files = Dir.glob(File.join(options[:folder], '*.sql'))

if sql_files.empty?
  puts Color.red("No SQL files found in folder #{options[:folder]}")
  exit 1
end

# Create MySQL client connection
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], DB_NAME, CONFIG['path'])

# Counters for reporting
total_files = sql_files.size
success_count = 0
fail_count = 0

# Array to store the names of files that failed execution
failed_files = []

puts Color.bold("Starting to run #{total_files} SQL file(s) in folder '#{options[:folder]}' on database '#{DB_NAME}'.")

sql_files.each do |file|
  print "Running #{file}... "
  if CLIENT.run_file(file)
    success_count += 1
    puts Color.green("success")
  else
    fail_count += 1
    failed_files << file
    puts Color.red("failed")
  end
end

# Print out failed files if any
unless failed_files.empty?
  puts Color.red("\nThe following files failed to execute:")
  failed_files.each do |failed_file|
    puts Color.red(" - #{failed_file}")
  end
end

# Summary report
puts Color.bold("\nExecution Summary:")
puts Color.bold("Total Files: #{total_files}")
puts Color.green("Successful: #{success_count}")
puts Color.red("Failed: #{fail_count}")
