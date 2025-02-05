#!/usr/bin/env ruby
require 'open3'
require 'yaml'
require 'tempfile'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

module TestSuite
  # Configuration
  CONFIG = YAML.load_file('config.yaml')
  MYSQL_CONFIG = CONFIG['mysql']
  MYSQL_CLIENT_PATH = MYSQL_CONFIG['path']
  DB_USER  = MYSQL_CONFIG['user']
  DB_PORT  = MYSQL_CONFIG['port']
  DB_HOST  = MYSQL_CONFIG['host']
  DB_NAME  = MYSQL_CONFIG['name']

  # Runs a series of setup commands.
  # +setup_commands+ should be an Array of hashes, each with keys :cmd and :desc.
  def self.run_initial_setup(setup_commands)
    setup_commands.each do |setup|
      puts Color.bold("Setup: #{setup[:cmd]}")
      stdout, stderr, status = Open3.capture3(setup[:cmd])
      unless status.success?
        puts Color.red("Error during setup (#{setup[:desc]}):")
        puts stderr
        exit 1
      else
        puts Color.green("Setup success.")
      end
      puts ''
    end
  end

  # Determines which diff command to use.
  # Prefers 'colordiff' if available; otherwise, falls back to plain 'diff'.
  def self.diff_command_prefix
    if system('which colordiff > /dev/null 2>&1')
      'colordiff -u'
    else
      'diff -u'
    end
  end

  # Executes a command, captures its output, and compares it with an expected output file.
  #
  # +command+::             The command to run.
  # +expected_output_file+:: The path to the file containing the expected output.
  #
  # @return [Boolean] true if the output matches the expected output, false otherwise.
  def self.run_command(command, expected_output_file)
    stdout, stderr, status = Open3.capture3(command)

    unless status.success?
      puts Color.red("Error executing command:")
      puts stderr
      return false
    end

    # Convert literal "\n" into real newlines in the output.
    processed_output = stdout.gsub('\\n', "\n")

    success = nil
    Tempfile.open('actual_output') do |temp|
      temp.write(processed_output)
      temp.flush

      diff_cmd_prefix = diff_command_prefix
      full_diff_command = "#{diff_cmd_prefix} #{expected_output_file} #{temp.path}"

      diff_out, _diff_err, diff_status = Open3.capture3(full_diff_command)

      if diff_status.success?
        success = true
      else
        puts Color.yellow("Differences found between actual output and expected output:")
        puts diff_out
        success = false
      end
    end

    success
  end

  # A class representing a SQL job that compares command output with an expected file.
  class SQLJob
    attr_reader :sql_file, :expected_file

    # +sql_file+::      The path to the SQL file.
    # +expected_file+:: The path to the expected output file.
    def initialize(sql_file, expected_file)
      @sql_file = sql_file
      @expected_file = expected_file
    end

    # Builds the MySQL command using the global configuration.
    def command
      "#{MYSQL_CLIENT_PATH} -u#{DB_USER} --local-infile=1 --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{@sql_file}"
    end

    # Executes the SQL job and runs the diff test.
    #
    # @return [Boolean] true if the diff test passed, false otherwise.
    def run
      puts Color.bold("Running SQL job using #{@sql_file}...")
      TestSuite.run_command(command, @expected_file)
    end
  end
end
