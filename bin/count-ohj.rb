#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'
require 'csv'
require 'fileutils'

require_relative '../lib/mysql'

# Load MySQL configuration
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], true)

ALWAYS_PROPOSE_HINT = '/*+ SET_OPTIMISM_FUNC(SIGMOID) */'

def parse_options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] INPUT_DIR"
    opts.on("--join-buffer-size SIZE", "Set join buffer size (in bytes)") do |size|
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

def count_optimistic(input_dir)
  mapping = {}
  Dir[File.join(input_dir, '*.sql')].each do |file|
    # Read the SQL file and collapse it into a single line
    query = File.read(file).lines.map(&:strip).join(' ')
    # Insert the hint right after the SELECT keyword
    modified_query = query.sub(/select\s+/i, "SELECT #{ALWAYS_PROPOSE_HINT} ")
    # Construct the EXPLAIN query with the modified query
    explain_query = "EXPLAIN FORMAT=tree #{modified_query}"
    stdout, _stderr = CLIENT.run_query_get_stdout(explain_query)
    # Count the occurrences of "optimistic hash join" (case-insensitive)
    join_count = stdout.scan(/optimistic hash join/i).size
    # Extract the query name (without extension)
    query_name = File.basename(file, '.sql')
    mapping[query_name] = join_count
  end
  mapping
end

def run
  options = parse_options

  # If join-buffer-size option is provided, set it globally in MySQL
  if options[:join_buffer_size]
    buffer_size = options[:join_buffer_size].to_i
    CLIENT.run_query_get_stdout("SET GLOBAL join_buffer_size = #{buffer_size}")
  end

  input_dir = options[:input_dir]
  results = count_optimistic(input_dir)

  # Ensure the results directory exists
  output_dir = './results'
  FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

  # Prepare CSV file path; include join buffer size in the file name if provided
  file_name = if options[:join_buffer_size]
                "ohj-count-inf-memory-#{options[:join_buffer_size]}.csv"
              else
                'ohj-count-inf-memory.csv'
              end
  file_path = File.join(output_dir, file_name)

  # Write results to CSV
  CSV.open(file_path, 'w') do |csv|
    csv << ['Query Name', 'Optimistic Hash Join Count']
    results.each do |query_name, count|
      csv << [query_name, count]
    end
  end

  puts "Successfully written to #{file_path}"
end

run if __FILE__ == $PROGRAM_NAME
