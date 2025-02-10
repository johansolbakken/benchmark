#!/usr/bin/env ruby
require 'shellwords'
require 'fileutils'

# ============================
# Configuration Parameters
# ============================

# MySQL credentials and target database
MYSQL_USER     = "root"
MYSQL_DB       = "test_sort_hashjoin_db"

# Benchmarking parameters for hyperfine
WARMUP_RUNS   = 2
MEASURED_RUNS = 5

# List of optimism levels and functions
OPTIMISM_VALUES   = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
OPTIMISM_FUNCTIONS = ['NONE', 'LINEAR', 'CLAMPED', 'SIGMOID', 'EXPONENTIAL']

# Folder and file to store the results
RESULTS_FOLDER = "results"
RESULTS_FILE   = File.join(RESULTS_FOLDER, "benchmark_results.json")

# Create the results folder if it doesn't exist
FileUtils.mkdir_p(RESULTS_FOLDER)

# ============================
# Helper: Build MySQL Command
# ============================

# Returns a MySQL command string that includes the given query hint.
def generate_command(hint)
  # Construct the SQL query with the hint inserted in the SELECT comment.
  sql = "USE #{MYSQL_DB}; SELECT #{hint} " \
        "a.id AS table_a_id, a.name, a.value, " \
        "b.id AS table_b_id, b.description, b.timestamp_col " \
        "FROM table_a AS a " \
        "JOIN table_b AS b ON b.a_id = a.id " \
        "ORDER BY b.a_id ASC;"
  # Build the command that calls mysql in non-interactive mode.
  # The query output is redirected to /dev/null.
  cmd = "mysql -u #{MYSQL_USER} --host=127.0.0.1 --port=13000 -e \"#{sql}\" > /dev/null"
  cmd
end

# ============================
# Build List of Commands
# ============================

commands = []

# 1. Baseline configuration
baseline_hint = "/*+ DISABLE_OPTIMISTIC_HASH_JOIN */"
commands << generate_command(baseline_hint)

# 2. All combinations of SET_OPTIMISM_LEVEL and SET_OPTIMISM_FUNC
OPTIMISM_VALUES.each do |level|
  OPTIMISM_FUNCTIONS.each do |func|
    hint = "/*+ SET_OPTIMISM_LEVEL(#{level}) SET_OPTIMISM_FUNC(#{func}) */"
    commands << generate_command(hint)
  end
end

puts "Total commands to benchmark: #{commands.size}"
puts "The following MySQL commands will be benchmarked (with warmup=#{WARMUP_RUNS} and runs=#{MEASURED_RUNS}):"
commands.each_with_index do |cmd, idx|
  puts "#{idx + 1}: #{cmd}"
end

# ============================
# Run Hyperfine with Export Option
# ============================

# Build the hyperfine argument list.
# We use Ruby's system() call with multiple arguments to bypass shell quoting issues.
hyperfine_args = [
  "hyperfine",
  "--warmup", WARMUP_RUNS.to_s,
  "--runs", MEASURED_RUNS.to_s,
  "--export-json", RESULTS_FILE
] + commands

puts "\nInvoking hyperfine..."
# Using system with the splat operator to pass each argument separately.
success = system(*hyperfine_args)

if success
  puts "\nBenchmarking complete. Results have been saved to #{RESULTS_FILE}"
else
  puts "\nAn error occurred while running hyperfine."
end

exit(success ? 0 : 1)
