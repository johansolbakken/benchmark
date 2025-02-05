#!/usr/bin/env ruby
#
require 'open3'
require 'yaml'
require 'tempfile'

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

##
# Run initial setup:
# 1. Generate a dataset with 10,000 rows each.
# 2. Prepare MySQL.
setup_commands = [
  { cmd: "ruby bin/generate_sort_hashjoin_dataset.rb 10000 10000", desc: "Generating dataset (10000, 10000)" },
  { cmd: "ruby bin/benchmark.rb --prepare-mysql", desc: "Preparing MySQL" }
]

setup_commands.each do |setup|
  puts Color.bold("Setup: #{setup[:desc]} using command: #{setup[:cmd]}")
  stdout, stderr, status = Open3.capture3(setup[:cmd])
  if !status.success?
    puts Color.red("Error during setup (#{setup[:desc]}):")
    puts stderr
    exit 1
  else
    puts Color.green("Setup succeeded for: #{setup[:desc]}")
  end
  puts Color.gray("---------------------------------------")
end

##
# Determines which diff command to use.
# It prefers 'colordiff' if available; otherwise, it falls back to plain 'diff'.
#
# @return [String] the diff command to use.
def diff_command_prefix
  if system('which colordiff > /dev/null 2>&1')
    'colordiff -u'
  else
    'diff -u'
  end
end

##
# Executes a command, captures its output, and compares it to an expected output file.
#
# @param command [String] the command to run.
# @param expected_output_file [String] path to the file containing the expected output.
def run_command(command, expected_output_file)
  stdout, stderr, status = Open3.capture3(command)

  if !status.success?
    puts Color.red("Error executing command:")
    puts stderr
    return
  end

  # Convert literal "\n" into real newlines in the actual output.
  processed_output = stdout.gsub('\\n', "\n")

  Tempfile.open('actual_output') do |temp|
    temp.write(processed_output)
    temp.flush

    diff_cmd_prefix = diff_command_prefix
    full_diff_command = "#{diff_cmd_prefix} #{expected_output_file} #{temp.path}"

    diff_out, diff_err, diff_status = Open3.capture3(full_diff_command)

    if diff_status.success?
      puts Color.green("Output matches expected output.")
    else
      puts Color.yellow("Differences found between actual output and expected output:")
      puts diff_out
    end
  end
end

##
# A class that encapsulates a SQL file and its expected output file.
class SQLJob
  attr_reader :sql_file, :expected_file

  # Initialize with paths to the SQL file and the expected output file.
  #
  # @param sql_file [String] the path to the SQL file.
  # @param expected_file [String] the path to the expected output file.
  def initialize(sql_file, expected_file)
    @sql_file = sql_file
    @expected_file = expected_file
  end

  # Builds the MySQL command using the global configuration variables.
  #
  # @return [String] the command to execute.
  def command
    "#{MYSQL_CLIENT_PATH} -u#{DB_USER} --local-infile=1 --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{@sql_file}"
  end

  # Runs the SQL command and compares its output with the expected file.
  def run
    puts Color.bold("Running SQL job using #{@sql_file}...")
    run_command(command, @expected_file)
  end
end

job_definitions = [
  { sql: "./homemade_dataset/homemade.sql",           expected: "./homemade_dataset/homemade.expected" },
  { sql: "./homemade_dataset/homemade_disabled.sql",  expected: "./homemade_dataset/homemade_disabled.expected" }
]

jobs = job_definitions.map { |job| SQLJob.new(job[:sql], job[:expected]) }

jobs.each do |job|
  job.run
  puts Color.gray("---------------------------------------")
end


##
# Helper method to run the explain-analyze query test.
#
# This method first invokes the dataset generation command with the given arguments.
# Then it executes a fixed EXPLAIN ANALYZE query (your provided query) against the MySQL server,
# and checks if all expected substrings appear in the output.
#
# @param generate_args [String] the arguments to pass to the dataset generator.
# @param expected_substrings [Array<String>] the substrings expected to appear in the query output.
def run_explain_test(generate_args, expected_substrings)
  # 1. Run the dataset generation command.
  generate_command = "ruby bin/generate_sort_hashjoin_dataset.rb #{generate_args}"
  puts Color.bold("Running dataset generator: #{generate_command}")
  gen_stdout, gen_stderr, gen_status = Open3.capture3(generate_command)
  if !gen_status.success?
    puts Color.red("Error running dataset generation:")
    puts gen_stderr
    return
  end

  # 2. Define the query.
  query = <<~SQL
    USE test_sort_hashjoin_db;
    EXPLAIN ANALYZE
    SELECT
      a.id AS table_a_id,
      a.name,
      a.value,
      b.id AS table_b_id,
      b.description,
      b.timestamp_col
    FROM table_a AS a
    JOIN table_b AS b
      ON b.a_id = a.id
    ORDER BY b.a_id ASC;
  SQL

  # 3. Execute the query using the MySQL client.
  # We pipe the query as stdin_data.
  puts Color.bold("Running benchmark query:")
  bench_stdout, bench_stderr, bench_status = Open3.capture3(
    "#{MYSQL_CLIENT_PATH} -u#{DB_USER} --local-infile=1 --port=#{DB_PORT} --host=#{DB_HOST}",
    stdin_data: query
  )
  if !bench_status.success?
    puts Color.red("Error running benchmark query:")
    puts bench_stderr
    return
  end

  # 4. Check that all expected substrings are present in the output.
  all_found = true
  expected_substrings.each do |substring|
    if bench_stdout.include?(substring)
      puts Color.green("Found expected substring: #{substring}")
    else
      puts Color.red("Missing expected substring: #{substring}")
      all_found = false
    end
  end

  if all_found
    puts Color.green("Test passed.")
  else
    puts Color.yellow("Test failed.")
  end

  puts Color.gray("---------------------------------------")
end

# New Tests using the provided query:
#
# Test 1:
#   Generate a small dataset:
#     ruby bin/generate_sort_hashjoin_dataset.rb 100 100
#   Then run the benchmark query.
#   Expected substrings:
#     "(optimistic hash join!)" and "went_on_disk=false"
run_explain_test("100 100", ["(optimistic hash join!)", "(went_on_disk=false)"])

# Test 2:
#   Generate a larger dataset:
#     ruby bin/generate_sort_hashjoin_dataset.rb 100000 100000
#   Then run the benchmark query.
#   Expected substrings:
#     "(optimistic hash join!)" and "went_on_disk=true"
run_explain_test("100000 100000", ["(optimistic hash join!)", "(went_on_disk=true)"])
