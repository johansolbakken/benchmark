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
