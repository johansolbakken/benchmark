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
    stdin.close

    threads = []
    threads << Thread.new do
      stdout.each_line do |line|
        # Replace literal \n with actual newlines, then print each line
        line.gsub("\\n", "\n").each_line do |sub_line|
          puts sub_line
        end
      end
    end

    threads << Thread.new do
      stderr.each_line do |line|
        # Replace literal \n with actual newlines, then print each line
        line.gsub("\\n", "\n").each_line do |sub_line|
          warn sub_line
        end
      end
    end

    exit_status = wait_thr.value
    threads.each(&:join)

    unless exit_status.success?
      puts "Error: Command exited with status #{exit_status.exitstatus}"
      exit 1
    end
  end
end

# TODO(Johan): this is probably not needed. investigate in future.
# Takes a long time to run this script, so will postpone investigation.
def enable_local_inline()
  run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --port=#{DB_PORT} --host=#{DB_HOST} -e 'SET GLOBAL local_infile=1;'")
end

# Parsing arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: run_queries.rb [options]"

  opts.on("--setup", "Setup the database with schema and foreign key indexes") do
    options[:setup] = true
  end

  opts.on("--run FILE", "Run a specific sql file") do |query|
    options[:query] = query
  end

  opts.on("--feed", "Feed all .gz files in the downloads folder to the database") do
    options[:feed] = true
  end

  opts.on("--explain", "Explain analyze") do
    options[:explain] = true
  end
end.parse!

# Main
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
    file = options[:query]
    explain = ""
    if options[:explain]
      explain = "EXPLAIN ANALYZE "
    end
    query = ""
    begin
      query = File.read(file)
    rescue StandardError => e
      puts e
      exit 1
    end
    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER}  --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} -e \"#{explain}#{query}\"")
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
  puts "No valid subcommand provided. Use --setup to setup the database, --run to run files, or --feed to feed data."
end
