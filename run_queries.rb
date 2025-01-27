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

def run_command(command)
  stdout, stderr, status = Open3.capture3(command)
  unless status.success?
    puts "Error: #{stderr}"
    exit 1
  end
  stdout
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
end.parse!

if options[:setup]
  begin
    puts "Setting up the database..."

    run_command("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} -e 'CREATE DATABASE IF NOT EXISTS #{DB_NAME};'")

    schema_file = File.join(SQL_PATH, 'schema.sql')
    puts "Importing schema: #{schema_file}"
    run_command("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{schema_file}")

    fkindexes_file = File.join(SQL_PATH, 'fkindexes.sql')
    puts "Importing foreign key indexes: #{fkindexes_file}"
    run_command("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} < #{fkindexes_file}")

    puts "Database setup completed."
  rescue StandardError => e
    puts "An error occurred during setup: #{e.message}"
  end
elsif options[:query]
  begin
    query = options[:query]
    puts "Running query: #{query}"

    result = run_command("#{MYSQL_CLIENT_PATH} -u#{DB_USER} --password=#{DB_PASSWORD} --port=#{DB_PORT} --host=#{DB_HOST} #{DB_NAME} -e \"#{query}\"")
    puts result
  rescue StandardError => e
    puts "An error occurred while running the query: #{e.message}"
  end
else
  puts "No valid subcommand provided. Use --setup to setup the database or --run to run queries."
end
