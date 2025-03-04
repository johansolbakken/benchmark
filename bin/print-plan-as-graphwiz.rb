#!/usr/bin/env ruby
require 'optparse'
require 'yaml'
require 'terminal-table'
require 'csv'
require 'json'
require 'fileutils'
require_relative '../lib/mysql'

# Load MySQL configuration and create a client.
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'])

# Convert a JSON query plan to DOT graph format.
def json_to_dot(data)
  dot_lines = [
    'digraph QueryPlan {',
    '  node [fontname="Helvetica" shape=none]',
    '  edge [arrowhead=none]'
  ]

  @node_counter = 0
  nodes = []
  edges = []

  traverse = lambda do |node|
    current_id = @node_counter
    label = node["operation"] || "Node"
    label = label.gsub(/Inner hash join/, 'Optimistic Hash Join') if node['was_optimistic_hash_join']
    label = label.gsub('"', '\"')
    nodes << "  node#{current_id} [label=\"#{label}\"];"
    @node_counter += 1

    if node["inputs"].is_a?(Array)
      node["inputs"].each do |child|
        child_id = traverse.call(child)
        edges << "  node#{current_id} -> node#{child_id};"
      end
    end
    current_id
  end

  traverse.call(data["query_plan"])
  dot_lines.concat(nodes).concat(edges)
  dot_lines << "}"
  dot_lines.join("\n")
end

def run
  # Read the SQL query from file and prepare the EXPLAIN statement.
  query = File.read('./job-order-queries/10a.sql').lines.map(&:strip).join(' ')
  explain_query = "EXPLAIN FORMAT=json #{query}"
  stdout, _stderr = CLIENT.run_query_get_stdout(explain_query)
  text_without_newlines = stdout.gsub(/\\n/, "")
  json_text = text_without_newlines.delete_prefix("EXPLAIN\n")
  data = JSON.parse(json_text)

  puts JSON.pretty_generate(data)

  # Generate and save the DOT graph.
  dot_output = json_to_dot(data)
  File.write('query_plan.dot', dot_output)
  puts 'DOT file has been written to query_plan.dot'

  system('dot -Tpng -Gdpi=600 -o query_plan.png query_plan.dot')
  puts 'Successful success!'
end

run if __FILE__ == $PROGRAM_NAME
