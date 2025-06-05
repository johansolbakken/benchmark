#!/usr/bin/env ruby
# NOTE: only the sections marked ➊–➌ differ from your original file
require 'optparse'
require 'yaml'
require 'json'
require 'fileutils'

require_relative '../lib/mysql'

# ──────────────────────  configuration  ──────────────────────
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'],
                           CONFIG['port'],
                           CONFIG['host'],
                           CONFIG['name'],
                           CONFIG['path'],
                           true)

# ───────────────────  ➊ inject_hint helper  ──────────────────
# Insert +hint+ after the *first top-level* SELECT (skips CTEs).
def inject_hint(sql, hint)
  depth = 0
  i     = 0
  while i < sql.length
    depth += 1 if sql[i] == '('
    depth -= 1 if sql[i] == ')'
    if depth.zero? && sql[i, 6].casecmp('select').zero?
      return sql[0, i] + "SELECT #{hint} " + sql[i + 6..]
    end
    i += 1
  end
  sql.sub(/\bSELECT\b/i, "SELECT #{hint}") # fallback
end

# ────────────────  json → dot (unchanged)  ──────────────────
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
    current = @node_counter
    label = node['operation'] || 'Node'
    if node['was_optimistic_hash_join']
      label = label.gsub('Inner hash join',  'Optimistic Hash Join')
                   .gsub('Left hash join',   'Optimistic Outer Hash Join')
    end
    label = label.gsub('"', '\"')

    if truncate
      map = {
        'Nested loop inner join'     => 'NLJ',
        'Nested loop left join'      => 'Outer NLJ',
        'Optimistic Hash Join'       => 'OOHJ',
        'Optimistic Outer Hash Join' => 'Outer OOHJ',
        'Index lookup'               => 'IDX',
        'Single-row index lookup'    => '1IDX',
        'PRIMARY'                    => 'PRI',
        'Table scan'                 => 'TS',
        'Inner hash join'            => 'HJ',
        'Left hash join'             => 'Outer HJ'
      }
      label = label.gsub(/\(cost=[^)]+\)/, '').strip
      map.each { |k, v| label.gsub!(k, v) }
    end

    nodes << %(  node#{current} [label="#{label}"];)
    @node_counter += 1

    if node['inputs'].is_a?(Array)
      node['inputs'].each do |child|
        child_id = traverse.call(child)
        edges << %(  node#{current} -> node#{child_id};)
      end
    end
    current
  end

  root = data['query_plan'] || data['query_block'] || data   # ➋ JSON key fallback
  traverse.call(root)

  (dot_lines + nodes + edges + ['}']).join("\n")
end

# ─────────────────────────  main  ───────────────────────────
def run(input_sql_file, output_pdf, hint, show_json, keep_dot, truncate, database_override)
  sql = File.read(input_sql_file).lines.map(&:strip).join(' ')
  sql.sub!(/;\s*\z/, '')                         # ➌ drop trailing “;”
  sql = inject_hint(sql, hint) unless hint.empty?

  CLIENT.use_database(database_override) if database_override

  explain_query = "EXPLAIN FORMAT=json #{sql}"   # prefixed, not search-replaced
  stdout, = CLIENT.run_query_get_stdout(explain_query)
  json_text = stdout.gsub(/\\n/, '').sub(/^EXPLAIN/, '')
  data = JSON.parse(json_text)
  puts JSON.pretty_generate(data) if show_json

  dot = json_to_dot(data, truncate)
  dot_file = 'query_plan.dot'
  File.write(dot_file, dot)
  FileUtils.mkdir_p(File.dirname(output_pdf))
  system("dot -Tpdf -Gdpi=300 -o #{output_pdf} #{dot_file}")
  File.delete(dot_file) unless keep_dot
  puts "PDF written to #{output_pdf}"
end

# ───────────────── CLI (original, slightly tidied) ──────────
options = {
  show_json: false, keep_dot: false, truncate: false,
  mode: nil, output_pdf: nil, database: nil
}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options] input.sql"

  opts.on('--baseline', 'Disable OOHJ') { options[:mode] = :baseline }
  opts.on('--oohj', 'Enable OOHJ')      { options[:mode] = :oohj }
  opts.on('--database=DB', 'Override DB')          { |db| options[:database] = db }
  opts.on('-oFILE', '--output=FILE', 'PDF output') { |f| options[:output_pdf] = f }
  opts.on('--show-json', 'Print JSON')             { options[:show_json] = true }
  opts.on('-c', '--keep-dot', 'Keep .dot')         { options[:keep_dot] = true }
  opts.on('--truncate', 'Short labels')            { options[:truncate] = true }
end.order!

abort('input file missing')          if ARGV.empty?
abort('pick --baseline or --oohj')   if options[:mode].nil?
abort('-o/--output is required')     if options[:output_pdf].nil?

hint =
  case options[:mode]
  when :baseline then '/*+ DISABLE_OPTIMISTIC_HASH_JOIN */'
  when :oohj     then '/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.8) */'
  end

run(ARGV[0], options[:output_pdf], hint, options[:show_json],
    options[:keep_dot], options[:truncate], options[:database])
