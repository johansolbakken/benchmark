#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'

require_relative '../lib/mysql'

# Load MySQL configuration
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

# Count join occurrences in SQL queries from the job-queries directory

=begin
def estimate_cardinalities
  Dir['./job-order-queries/*.sql'].each do |file|
    query = File.read(file).lines.map(&:strip).join(' ')
    stdout, _, _ = CLIENT.run_query_get_stdout("EXPLAIN ANALYZE #{query}")
    # Write the stdout to a file "temp.txt" for debugging
    File.open('temp.txt', 'w') do |f|
      f.puts stdout
    end
    break
  end
end
=end

def estimate_cardinalities
  estimate_and_actual = []
  Dir['./job-order-queries/*.sql'].each do |file|
    query = File.read(file).lines.map(&:strip).join(' ')
    stdout = File.read('./bin/temp.txt')
    # Take the stoud string, and split it into a list that is divided by the symbol "->"
    # This symbol is used to separate the different parts of the query plan

    query_plan = stdout.split('\\n')
    
    # Iterate through query plan list, and for each element, check if "rows=" is present twice.
    # If rows= is present twice, add the two values to the estimate_and_actual list. 
    # The list should be structured like this: [{estimated=x, actual=x}, {estimated=x, actual=x}, ...]
    query_plan.each do |element|
      if element.include?("rows=") && element.scan("rows=").length == 2
        depth = element.split("->")[0].size / 4
        # Estimates can be on two forms: standard double or scientific notation
        estimate = element.scan(/rows=(\d+\.?\d+e\+\d+|\d+)/)[0][0].to_f
        actual = element.scan(/rows=(\d+\.?\d+e\+\d+|\d+)/)[1][0].to_f
        estimate_and_actual << {estimated: estimate, actual: actual, depth: depth}
      end
    end

    max_depth = estimate_and_actual.map { |x| x[:depth] }.max
    # invert depth
    estimate_and_actual.each do |x|
      x[:depth] = max_depth - x[:depth]
    end

    # sort by depth
    estimate_and_actual.sort_by! { |x| x[:depth] }
    puts estimate_and_actual
    return estimate_and_actual
    break
  end
end

def run
  estimate_cardinalities
end

run if __FILE__ == $PROGRAM_NAME
