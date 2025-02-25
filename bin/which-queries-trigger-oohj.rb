#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'

require_relative '../lib/mysql'

# Load MySQL configuration
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

# Count join occurrences in SQL queries from the job-queries directory
def count_joins
  files_with_optimistic = []
  Dir['./job-order-queries/*.sql'].each do |file|
    query = File.read(file).lines.map(&:strip).join(' ')
    stdout, _, _ = CLIENT.run_query_get_stdout("EXPLAIN FORMAT=tree #{query}")
    join_count = stdout.scan(/optimistic/i).size
    if join_count > 0
      files_with_optimistic << file
    end
  end
  return files_with_optimistic.sort
end

def run
  files_with_optimistic = count_joins
  File.open('./results/oohj-queries.txt', 'w') do |f|
    files_with_optimistic.each do |file|
      f.puts File.basename(file, '.*')
    end
  end
  puts "Successfully written to ./results/oohj-queries.txt"
end

run if __FILE__ == $PROGRAM_NAME
