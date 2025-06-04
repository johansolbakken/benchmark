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
    label = label.gsub(/Left hash join/, 'Optimistic Outer Hash Join') if node['was_optimistic_hash_join']
    label = label.gsub('"', '\"')


    if truncate
      # Replace long join names with short codes
      map = {
        'Nested loop inner join' => 'NLJ',
        'Nested loop left join' => 'Outer NLJ',
        'Optimistic Hash Join' => 'OOHJ',
        'Optimistic Outer Hash Join' => 'Outer OOHJ',
        'Index lookup' => 'IDX',
        'Single-row index lookup' => '1IDX',
        'PRIMARY' => 'PRI',
        'Table scan' => 'TS',
        'Inner hash join' => 'HJ',
        'Left hash join' => 'Outer HJ',
      }

      # Remove cost info but keep ON / USING clauses
      label = label.gsub(/\(cost=[^)]+\)/, '').strip

      map.each do |find, replace|
        label.gsub!(find, replace)
      end
    end


    nodes << "  node#{current_id} [label=\"#{label}\"];"
    @node_counter += 1

    if node["inputs"].is_a?(Array)
      node["inputs"].each_with_index do |child, index|
        child_id = traverse.call(child)
        edge_label = ''
        edges << if edge_label
                   "  node#{current_id} -> node#{child_id} [label=\"#{edge_label}\"];"
                 else
                   "  node#{current_id} -> node#{child_id};"
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

def run(input_sql_file, output_pdf, hint, show_json, keep_dot, truncate, database_override)
  query = File.read(input_sql_file).lines.map(&:strip).join(' ')

  # Switch to selected database
  CLIENT.use_database(database_override) if database_override

  # Add hint
  query.sub!(/select/i, "SELECT #{hint}") if hint && !hint.empty?

  explain_query = "EXPLAIN FORMAT=json #{query}"
  stdout, _stderr = CLIENT.run_query_get_stdout(explain_query)
  text_without_newlines = stdout.gsub(/\\n/, "")
  json_text = text_without_newlines.delete_prefix("EXPLAIN\n")
  data = JSON.parse(json_text)

  puts JSON.pretty_generate(data) if show_json

  dot_output = json_to_dot(data, truncate)
  dot_file = 'query_plan.dot'
  File.write(dot_file, dot_output)
  puts "DOT file written to #{dot_file}"

  system("dot -Tpdf -Gdpi=300 -o #{output_pdf} #{dot_file}")
  puts "PDF file written to #{output_pdf}"

  File.delete(dot_file) unless keep_dot
end

# Default options
options = {
  show_json: false,
  output_pdf: nil,
  keep_dot: false,
  truncate: false,
  mode: nil,
  database: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options] input.sql"

  opts.on("--baseline", "Use baseline mode (disables OOHJ)") do
    options[:mode] = :baseline
  end

  opts.on("--oohj", "Use Optimistic Order-preserving Hash Join mode") do
    options[:mode] = :oohj
  end

  opts.on("--database=DB", "Database to use (overrides config.yaml)") do |db|
    options[:database] = db
  end

  opts.on("-oFILE", "--output=FILE", "Output PDF file name (required)") do |output|
    options[:output_pdf] = output
  end

  opts.on("--show-json", "Print JSON output") do
    options[:show_json] = true
  end

  opts.on("-c", "--keep-dot", "Keep intermediate DOT file") do
    options[:keep_dot] = true
  end

  opts.on("--truncate", "Truncate node labels") do
    options[:truncate] = true
  end
end.order!

# Check input file
if ARGV.empty?
  puts "Error: You must specify an input SQL file."
  exit 1
end

# Validate mode
if options[:mode].nil?
  puts "Error: You must specify either --baseline or --oohj."
  exit 1
end

# Validate output file
if options[:output_pdf].nil?
  puts "Error: You must specify an output PDF file with -o or --output."
  exit 1
end

# Determine hint
hint = case options[:mode]
       when :baseline
         '/*+ DISABLE_OPTIMISTIC_HASH_JOIN */'
       when :oohj
         '/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.8) */'
       end

# Execute
run(
  ARGV[0],
  options[:output_pdf],
  hint,
  options[:show_json],
  options[:keep_dot],
  options[:truncate],
  options[:database]
)
