#!/usr/bin/env ruby

require 'optparse'
require 'open3'
require 'yaml'

config = YAML.load_file('config.yaml')

mysql_config = config['mysql']
MYSQL_CLIENT_PATH = mysql_config['path']
DB_USER = 'root'
DB_PASSWORD = ''
DB_PORT = '13000'
DB_HOST = '127.0.0.1'
DB_NAME = 'test'
SQL_PATH = '3rdparty/job'
DOWNLOADS_PATH = './downloads'

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

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: mysql_client.rb [options]"

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

    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} -e 'CREATE DATABASE IF NOT EXISTS #{DB_NAME};'")

    schema_file = File.join(SQL_PATH, 'schema.sql')
    puts "Importing schema: #{schema_file}"
    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{schema_file}")

    fkindexes_file = File.join(SQL_PATH, 'fkindexes.sql')
    puts "Importing foreign key indexes: #{fkindexes_file}"
    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{fkindexes_file}")

    puts "Database setup completed."
  rescue StandardError => e
    puts "An error occurred during setup: #{e.message}"
    exit 1
  end
elsif options[:query]
  begin
    query = options[:query]
    puts "Running query: #{query}"

    run_command_stream("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} -e \"#{query}\"")
  rescue StandardError => e
    puts "An error occurred while running the query: #{e.message}"
    exit 1
  end
elsif options[:feed]
  begin
    puts "Feeding .gz files to the database using imdbpy2sql.py..."

    imdbpy_command = "python ./3rdparty/cinemagoer/bin/imdbpy2sql.py " \
                     "--mysql-innodb "\
                     "-d #{DOWNLOADS_PATH} " \
                     "-u mysql://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"
    run_command_stream(imdbpy_command)

    puts "Data feeding completed."
  rescue StandardError => e
    puts "An error occurred during feeding: #{e.message}"
    exit 1
  end
else
  puts "No valid subcommand provided. Use --setup to setup the database, --run to run queries, or --feed to feed data."
end
