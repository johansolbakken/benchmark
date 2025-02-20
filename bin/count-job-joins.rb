#!/usr/bin/env ruby

require 'optparse'
require 'yaml'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

# Configuration
CONFIG = YAML.load_file('config.yaml')['mysql']

# Create a MySQL CLIENT from lib/mysql.rb
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'])

# Fetch queries from ./job and add EXPLAIN FORMAT = TREE at the start of each query
def count_joins
  job_queries = Dir['./job-queries/*.sql']
  dict = {}
  job_queries.each do |file|
    query = File.read(file)
    query = query.split("\n").map(&:strip).join(' ')
    query = "EXPLAIN FORMAT = TREE #{query}"
    stdout, _, ok = CLIENT.run_query_get_stdout(query)
    count = 0
    stdout.split("->").each do |line|
      # Process each line of stdout here
      if line.downcase.include?("join")
      count += 1
      end
    end
    if dict.key?(count)
      dict[count] += 1
    else
      dict[count] = 1
    end
  end
  dict
end

def run()
  count_joins.sort.each do |key, value|
    puts "#{key} joins: #{value} queries"
  end
end

run() if __FILE__ == $PROGRAM_NAME
