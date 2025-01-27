#!/usr/bin/env ruby

require 'optparse'
require 'open3'
require 'yaml'

require_relative 'lib/sql_table_topological_sort'

config = YAML.load_file('config.yaml')

mysql_config = config['mysql']
MYSQL_CLIENT_PATH = mysql_config['path']
DB_USER = 'root'
DB_PORT = '13000'
DB_HOST = '127.0.0.1'
DB_NAME = 'imdbload'
SQL_PATH = './job'
DOWNLOADS_PATH = './dataset'

# This method now uses popen3 to stream output as the command runs.
def run_command_stream(command)
  puts "Executing: #{command}"

  Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
    # We won't be sending any input
    stdin.close

    # Create threads to read each stream line-by-line
    threads = []

    threads << Thread.new do
      stdout.each_line do |line|
        # Print lines from stdout immediately
        puts line
      end
    end

    threads << Thread.new do
      stderr.each_line do |line|
        # Print lines from stderr immediately
        warn line
      end
    end

    # Wait for the process to finish, then get its exit status
    exit_status = wait_thr.value

    # Make sure we've read everything
    threads.each(&:join)

    unless exit_status.success?
      # If the command failed, exit
      puts "Error: Command exited with status #{exit_status.exitstatus}"
      exit 1
    end
  end
end

def enable_local_inline()
  run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --port=#{DB_PORT} --host=#{DB_HOST} -e 'SET GLOBAL local_infile=1;'")
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: run_queries.rb [options]"

  opts.on("--setup", "Setup the database with schema and foreign key indexes") do
    options[:setup] = true
  end

  opts.on("--run QUERY", "Run a specific query") do |query|
    options[:query] = query
  end

  opts.on("--feed", "Feed all .gz files in the downloads folder to the database") do
    options[:feed] = true
  end
end.parse!

if options[:setup]
  begin
    puts "Setting up the database..."

    # Inspiration from this repo: https://github.com/noraej/JOB/blob/main/csv_files/imdb-create-tables.sql
    setup_commands = [
      "SET GLOBAL local_infile=1;",
      "DROP DATABASE IF EXISTS imdbload;",
      "CREATE DATABASE imdbload;",
      "USE imdbload;",
    ]

    setup_commands.each do |command|
      run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --port=#{DB_PORT} --host=#{DB_HOST} -e '#{command}'")
    end

    schema_file = File.join(SQL_PATH, 'schema.sql')
    puts "Importing schema: #{schema_file}"
    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER}  --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{schema_file}")

    fkindexes_file = File.join(SQL_PATH, 'fkindexes.sql')
    puts "Importing foreign key indexes: #{fkindexes_file}"
    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER}  --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{fkindexes_file}")

    puts "Database setup completed."
  rescue StandardError => e
    puts "An error occurred during setup: #{e.message}"
    exit 1
  end
elsif options[:query]
  begin
    query = options[:query]
    puts "Running query: #{query}"

    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER}  --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} -e \"#{query}\"")
  rescue StandardError => e
    puts "An error occurred while running the query: #{e.message}"
    exit 1
  end
elsif options[:feed]
  begin
    enable_local_inline

    sql = File.read("job/schema.sql")
    sorted_tables = Sql_Table_Topological_Sort.sort_tables(sql)
    sorted_tables.each do |name|
      file = File.expand_path("#{DOWNLOADS_PATH}/#{name}.csv")
      query = "LOAD DATA LOCAL INFILE '#{file}' INTO TABLE #{name} FIELDS TERMINATED BY ',';"
      run_command_stream("#{MYSQL_CLIENT_PATH} --local-infile=1 -u#{DB_USER}  --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} -e \"#{query}\"")
    end

    puts "Loaded all sql files into MySQL!"
  rescue StandardError => e
    puts "An error occurred during feeding: #{e.message}"
    exit 1
  end
else
  puts "No valid subcommand provided. Use --setup to setup the database, --run to run queries, or --feed to feed data."
end
