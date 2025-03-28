#!/usr/bin/env ruby
require 'optparse'
require 'yaml'
require 'json'
require 'fileutils'

require_relative '../lib/mysql'

# Load MySQL configuration and create a client.
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], true)

# Convert a JSON query plan to DOT graph format.
def json_to_dot(data, truncate)
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

    if truncate
      map = {
        'Nested loop inner join' => 'NLJ',
        'Optimistic Hash Join' => 'OOHJ',
        'Index lookup' => 'IDX',
        'Single-row index lookup' => '1IDX',
        'PRIMARY' => 'PRI',
        'Table scan' => 'TS',
        'Inner hash join' => 'HJ',
      }

      label = label.gsub(/using\s+\w+/, '')

      map.each do |find, replace|
        label.gsub!(find, replace)
      end
    end


    nodes << "  node#{current_id} [label=\"#{label}\"];"
    @node_counter += 1

    if node["inputs"].is_a?(Array)
      node["inputs"].each_with_index do |child, index|
        child_id = traverse.call(child)

        if label.downcase.include?('hash join') or label.downcase.include?('hj')
          probe = 'probe'
          if index > 0
            probe = 'build'
          end
          edges << "  node#{current_id} -> node#{child_id} [label=\"#{probe}\"];"
        else
        edges << "  node#{current_id} -> node#{child_id};"
        end
      end
    end
    current_id
  end

  traverse.call(data["query_plan"])
  dot_lines.concat(nodes).concat(edges)
  dot_lines << "}"
  dot_lines.join("\n")
end

def run(input_sql_file, show_json, output_png, keep_dot, hint, truncate)
  # Read and join SQL file lines into one query string.
  query = File.read(input_sql_file).lines.map(&:strip).join(' ')

  # If a hint is provided, modify the query by replacing the first occurrence of SELECT.
  if hint && !hint.empty?
    # Replace the first occurrence of SELECT (case insensitive) with "SELECT #{hint}"
    query.sub!(/select/i, "SELECT #{hint}")
  end

  explain_query = "EXPLAIN FORMAT=json #{query}"
  stdout, _stderr = CLIENT.run_query_get_stdout(explain_query)
  text_without_newlines = stdout.gsub(/\\n/, "")
  json_text = text_without_newlines.delete_prefix("EXPLAIN\n")
  data = JSON.parse(json_text)

  puts JSON.pretty_generate(data) if show_json

  dot_output = json_to_dot(data, truncate)
  dot_file = 'query_plan.dot'
  File.write(dot_file, dot_output)
  puts "DOT file has been written to #{dot_file}"

  system("dot -Tpng -Gdpi=600 -o #{output_png} #{dot_file}")
  puts "PNG file has been written to #{output_png}"

  File.delete(dot_file) unless keep_dot
  puts 'Successful success!'
end

options = {
  show_json: false,
  output_png: 'query_tree.png',
  keep_dot: false,
  truncate: false,
  hint: ""
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options] input_sql_file"

  opts.on("--show-json", "Print JSON output (default false)") do
    options[:show_json] = true
  end

  opts.on("-oOUTPUT", "--output=OUTPUT", "Output PNG file name (default query_tree.png)") do |output|
    options[:output_png] = output
  end

  opts.on("-c", "--keep-dot", "Keep the DOT file (default delete it)") do
    options[:keep_dot] = true
  end

  opts.on("--hint HINT", "SQL hint to be inserted after SELECT (example: '/*+ SET_OPTIMISM_FUNC(SIGMOID) */')") do |hint|
    options[:hint] = hint
  end

  opts.on("--truncate", "Truncate all nodes") do
    options[:truncate] = true
  end
end.parse!

if ARGV.empty?
  puts "Error: input SQL file is required."
  exit 1
end

input_sql_file = ARGV[0]
run(input_sql_file,
    options[:show_json],
    options[:output_png],
    options[:keep_dot],
    options[:hint],
    options[:truncate]) if __FILE__ == $PROGRAM_NAME
