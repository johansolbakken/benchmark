#!/usr/bin/env ruby
require 'fileutils'

MYSQL_USER = "root"
MYSQL_DB   = "imdbload"
MYSQL_HOST = "127.0.0.1"
MYSQL_PORT = "13000"

warmup_runs = 2
total_runs  = 5

query_dir="./job-order-queries"
queries = Dir.glob(File.join(query_dir, '*.sql')).shuffle
queries = queries.take(queries.size)
if queries.empty?
  puts "No SQL files found in directory: #{query_dir}"
  exit 1
end

# Example usage:
#   query = "  SELECT name, age FROM users WHERE age > 20"
#   hint  = "/*+ INDEX(users idx_age) */"
#
#   result = insert_hint(query, hint)
#   # Result: "  SELECT /*+ INDEX(users idx_age) */ name, age FROM users WHERE age > 20"
#
def insert_hint(query, hint)
  if query =~ /\A(\s*select\s+)/i
    prefix = $1     # Captures leading whitespace + SELECT + trailing whitespace
    rest   = query[prefix.size..-1]  # Gets everything after the SELECT part
    "#{prefix}#{hint} #{rest}"  # Reconstructs query with hint inserted
  else
    # If the query doesn't start with SELECT, return it unchanged.
    query
  end
end

def build_command_for_query(query_file, config_hint)
  content = File.read(query_file)
  modified_query = insert_hint(content, config_hint).strip
  sql = "USE #{MYSQL_DB}; #{modified_query}"
  escaped_sql = sql.gsub('"', '\"')
  "mysql -u #{MYSQL_USER} --host=#{MYSQL_HOST} --port=#{MYSQL_PORT} -e \"#{escaped_sql}\" > /dev/null"
end

def sanitize_filename(filename)
  filename.gsub(/[^0-9A-Za-z.\-]/, '_')
end

FileUtils.mkdir_p("results")

def run_configuration2(func, level, queries, warmup_runs, total_runs)
  config_hint = "/*+ SET_OPTIMISM_LEVEL(#{level}) SET_OPTIMISM_FUNC(#{func}) */"
  puts "=== Testing configuration: #{config_hint} ==="
  
  # Collect all test commands
  test_commands = []
  query_names = []
  
  queries.each do |query_file|
    base_query = File.basename(query_file, '.sql')  # Remove .sql extension
    puts "Running query: #{base_query} with configuration: #{config_hint}"
    
    # Build the MySQL command for this query and configuration
    test_cmd = build_command_for_query(query_file, config_hint)
    test_commands << test_cmd
    query_names << base_query
    
    puts "Added command to benchmark:\n#{test_cmd}\n"
  end
  
  # Prepare single result file for all queries
  result_file = File.join("results", "#{func}_#{level}_result.csv")
  
  # Build hyperfine's argument list with all commands
  hyperfine_args = [
    "hyperfine",
    "--warmup", warmup_runs.to_s,
    "--runs", total_runs.to_s,
    "--export-csv", result_file
  ]
  
  # Add command names using SQL base names
  test_commands.zip(query_names).each do |cmd, name|
    hyperfine_args.concat(["--command-name", name])
  end
  
  # Add all commands at the end
  hyperfine_args.concat(test_commands)
  
  puts "Running benchmarks for all queries..."
  puts "Results will be exported to: #{result_file}"
  
  # Invoke hyperfine with all commands
  success = system(*hyperfine_args)
  unless success
    puts "Error while benchmarking queries with configuration #{config_hint}."
  end
  
  puts "------------------------------------"
end

def run_baseline(queries, warmup_runs, total_runs)
  config_hint = "/*+ DISABLE_OPTIMISTIC_HASH_JOIN */"
  puts "=== Testing configuration: #{config_hint} ==="
  
  # Collect all test commands
  test_commands = []
  query_names = []
  
  queries.each do |query_file|
    base_query = File.basename(query_file, '.sql')  # Remove .sql extension
    puts "Running query: #{base_query} with configuration: #{config_hint}"
    
    # Build the MySQL command for this query and configuration
    test_cmd = build_command_for_query(query_file, config_hint)
    test_commands << test_cmd
    query_names << base_query
    
    puts "Added command to benchmark:\n#{test_cmd}\n"
  end
  
  # Prepare single result file for all queries
  result_file = File.join("results", "baseline_result.csv")
  
  # Build hyperfine's argument list with all commands
  hyperfine_args = [
    "hyperfine",
    "--warmup", warmup_runs.to_s,
    "--runs", total_runs.to_s,
    "--export-csv", result_file
  ]
  
  # Add command names using SQL base names
  test_commands.zip(query_names).each do |cmd, name|
    hyperfine_args.concat(["--command-name", name])
  end
  
  # Add all commands at the end
  hyperfine_args.concat(test_commands)
  
  puts "Running benchmarks for all queries..."
  puts "Results will be exported to: #{result_file}"
  
  # Invoke hyperfine with all commands
  success = system(*hyperfine_args)
  unless success
    puts "Error while benchmarking queries with configuration #{config_hint}."
  end
  
  puts "------------------------------------"
end

OPTIMISM_VALUES    = [0.0, 0.5, 1.0]
OPTIMISM_FUNCTIONS = ['NONE', 'LINEAR', 'SIGMOID', 'EXPONENTIAL']

run_baseline(queries, warmup_runs, total_runs)
OPTIMISM_FUNCTIONS.each do |func|
  OPTIMISM_VALUES.each do |level|
    run_configuration2(func, level, queries, warmup_runs, total_runs)
  end
end
