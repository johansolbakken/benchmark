#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'
require 'csv'

require_relative '../lib/mysql'

# Load MySQL configuration
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

def estimate_cardinalities
  estimate_and_actual = []
  Dir['./job-order-queries/*.sql'].each do |file|
    query = File.read(file).lines.map(&:strip).join(' ')
    stdout, _, _ = CLIENT.run_query_get_stdout("EXPLAIN ANALYZE #{query}")
    query_plan = stdout.split('\\n')
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
    # Invert depth
    estimate_and_actual.each do |x|
      x[:depth] = max_depth - x[:depth]
    end
    # Sort by depth
    estimate_and_actual.sort_by! { |x| x[:depth] }
    CSV.open('./results/cardinality-estimate-comparison.csv', 'w') do |csv|
      csv << ['estimated', 'actual', 'depth']
      estimate_and_actual.each do |row|
        csv << [row[:estimated], row[:actual], row[:depth]]
      end
    end
  end
end

def run
  estimate_cardinalities
end

run if __FILE__ == $PROGRAM_NAME
