#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'
require 'csv'

require_relative '../lib/mysql' 

# Load MySQL configuration
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

# Parse command line options
def parse_options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] INPUT_DIR"
    opts.on("--join-buffer-size SIZE", "Set join buffer size") do |size|
      options[:join_buffer_size] = size
    end
  end.parse!

  if ARGV.empty?
    puts "Error: Missing mandatory INPUT_DIR argument."
    puts "Usage: #{$PROGRAM_NAME} [options] INPUT_DIR"
    exit 1
  end

  options[:input_dir] = ARGV.shift
  options
end

# Find queries that use optimistic hash join and go on disk and write names of those queries to a file
def find_oohj_on_disk_queries(input_dir)
  files_with_optimistic = []
  Dir[File.join(input_dir, '*.sql')].each do |file|
    query = File.read(file).lines.map(&:strip).join(' ')
    stdout, _stderr = CLIENT.run_query_get_stdout("EXPLAIN ANALYZE #{query}")
    if stdout.include?('went_on_disk=true')
      files_with_optimistic << file
    end
  end
  file_path = "./results/oohj-queries-on-disk.txt"
  File.open(file_path, 'w') do |f|
    files_with_optimistic.each do |file|
      f.puts file
    end
  end
end

# Run all queries that use optimistic hash join and go on disk and save the output to a file
def run_queries_and_save_output(files_with_optimistic)
  files_with_optimistic.each do |file|
    query = File.read(file).lines.map(&:strip).join(' ')

    # Disable optimistic hash join
    #query = query.sub(/select\s+/i, "/*+ DISABLE_OPTIMISTIC_HASH_JOIN*/ ")

    stdout, _stderr = CLIENT.run_query_get_rows(query)
    file_path = "./results/#{File.basename(file)}.csv"
    CSV.open(file_path, 'w') do |csv|
      stdout.each do |row|
        csv << row
      end
    end
  end
end

def get_order_by_condition(query_name, input_dir)
  query = File.read("./#{input_dir}/#{query_name}.sql")
  order_by_condition = query.match(/order by (.*)/i)[1].gsub(";", "")
  order_by_condition 
end

def check_if_result_is_sorted_on_condition(file_name, condition)
  # Check in both ascending and descending order
  rows = CSV.read(file_name)
  header = rows.shift
  column_index = header.index(condition)
  rows.each_cons(2) do |row1, row2|
    if row1[column_index].downcase > row2[column_index].downcase
      # Print rows that break the order
      puts "Row 1: #{row1}"
      puts "Row 2: #{row2}"
      
      return false
    end
  end
  true
end


# Run the script
def run()
  options = parse_options
  input_dir = options[:input_dir]

  # If join-buffer-size option is provided, set it globally in MySQL
  if options[:join_buffer_size]
    buffer_size = Byte.parse(options[:join_buffer_size])
    CLIENT.run_query_get_stdout("SET GLOBAL join_buffer_size = #{buffer_size}")
  end

  # puts "Finding queries that use optimistic hash join and go on disk..."
  # files_with_optimistic = find_oohj_on_disk_queries(input_dir)

  # puts "Running the queries and saving the output to a file..."
  #files_with_optimistic = File.readlines('./results/oohj-queries-on-disk.txt').map(&:strip)
  #run_queries_and_save_output(files_with_optimistic)

  # ./job-order-queries/14c.sql
  # puts "Get the order by condition for query 14c..."
  #order_by_condition = get_order_by_condition("14c", input_dir)

  #puts "Checking if the output of 14c is sorted..."
  #puts check_if_result_is_sorted_on_condition("./results/14c.sql.csv", order_by_condition)

  # Iterate through all queries in oohj-queries-on-disk.txt, and check if result is sorted on condition in order by clause
  files_with_optimistic = File.readlines('./results/oohj-queries-on-disk.txt').map(&:strip)

  files_with_optimistic.each do |file|
    query_name = File.basename(file, '.sql')
    order_by_condition = get_order_by_condition(query_name, input_dir)
    csv_file_path = "./results/#{query_name}.sql.csv"
    puts "Order by condition for query #{query_name}: #{order_by_condition}"

    if File.exist?(csv_file_path)
      is_sorted = check_if_result_is_sorted_on_condition(csv_file_path, order_by_condition)
      puts "Query #{query_name}: Result is #{is_sorted ? 'sorted' : 'not sorted'} on condition '#{order_by_condition}'."
    else
      puts "CSV file for query #{query_name} not found. Skipping."
    end
  end







  #puts "Checking if the output of the queries is sorted..."
  #check_if_output_is_sorted(files_with_optimistic)
end

run()