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
  Dir['./job-queries/*.sql'].each_with_object(Hash.new(0)) do |file, join_counts|
    query = File.read(file).lines.map(&:strip).join(' ')
    stdout, _, _ = CLIENT.run_query_get_stdout("EXPLAIN FORMAT = TREE #{query}")
    join_count = stdout.scan(/join/i).size
    join_counts[join_count] += 1
  end
end

# Print the join count summary in a table format
def run
  rows = count_joins.sort.map { |joins, count| [joins, count] }
  table = Terminal::Table.new(title: "Join Count Summary", headings: ['Joins', 'Queries'], rows: rows)
  puts table
end

run if __FILE__ == $PROGRAM_NAME
