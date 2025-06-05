#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'yaml'
require 'json'
require 'fileutils'

require_relative '../lib/mysql'

# ──────────────────────────  configuration  ────────────────────────────────
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(
  CONFIG['user'],
  CONFIG['port'],
  CONFIG['host'],
  CONFIG['name'],
  CONFIG['path'],
  true
)

# ──────────────────────  helpers: hint injection  ──────────────────────────
# Inject +hint+ into the first *top-level* SELECT token (skips CTEs).
def inject_hint(sql, hint)
  depth = 0
  i     = 0
  while i < sql.length
    c = sql[i]
    depth += 1 if c == '('
    depth -= 1 if c == ')'
    if depth.zero? && sql[i, 6].casecmp('select').zero?
      return sql[0, i] + "SELECT #{hint} " + sql[i + 6..]
    end
    i += 1
  end
  # fallback – never raise
  sql.sub(/\bSELECT\b/i, "SELECT #{hint}")
end

# ──────────────────────  helpers: JSON → DOT  ──────────────────────────────
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
    label = node['operation'] || 'Node'
    label = label.gsub(/Inner hash join/,  'Optimistic Hash Join')  if node['was_optimistic_hash_join']
    label = label.gsub(/Left hash join/,   'Optimistic Outer Hash Join') if node['was_optimistic_hash_join']
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

    nodes << %(  node#{current_id} [label="#{label}"];)
    @node_counter += 1

    if node['inputs'].is_a?(Array)
      node['inputs'].each do |child|
        child_id = traverse.call(child)
        edges << %(  node#{current_id} -> node#{child_id};)
      end
    end
    current_id
  end

  root = data['query_plan'] || data['query_block'] || data
  traverse.call(root)

  dot_lines.concat(nodes).concat(edges)
  dot_lines << '}'
  dot_lines.join("\n")
end

# ───────────────────────────  main routine  ────────────────────────────────
def run(input_sql_file, output_pdf, hint, show_json, keep_dot, truncate, db_override)
  raw_sql = File.read(input_sql_file)
  raw_sql.gsub!(/\s+/, ' ')   # collapse whitespace
  raw_sql.sub!(/;\s*\z/, '')  # strip trailing semicolon
  raw_sql  = inject_hint(raw_sql, hint) if hint && !hint.empty?

  CLIENT.use_database(db_override) if db_override

  explain_query = "EXPLAIN FORMAT=json #{raw_sql}"  # prefix, not replace
  stdout, = CLIENT.run_query_get_stdout(explain_query)

  json_text = stdout.gsub(/\\n/, '').delete_prefix('EXPLAIN')
  data      = JSON.parse(json_text)

  puts JSON.pretty_generate(data) if show_json

  dot_output = json_to_dot(data, truncate)
  dot_file   = 'query_plan.dot'
  File.write(dot_file, dot_output)

  FileUtils.mkdir_p(File.dirname(output_pdf))
  system("dot -Tpdf -Gdpi=300 -o #{output_pdf} #{dot_file}")

  File.delete(dot_file) unless keep_dot
  puts "PDF written to #{output_pdf}"
end

# ───────────────────────────  CLI parsing  ─────────────────────────────────
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

  opts.on('--baseline', 'Use baseline mode (disables OOHJ)')   { options[:mode] = :baseline }
  opts.on('--oohj',     'Use Optimistic Hash Join mode')       { options[:mode] = :oohj }
  opts.on('--database=DB', 'Database override')                { |db| options[:database] = db }
  opts.on('-oFILE', '--output=FILE', 'Output PDF (required)')  { |f| options[:output_pdf] = f }
  opts.on('--show-json',   'Print JSON plan')                  { options[:show_json] = true }
  opts.on('-c', '--keep-dot', 'Keep intermediate DOT')         { options[:keep_dot] = true }
  opts.on('--truncate',    'Shorten node labels')              { options[:truncate] = true }
end.order!

abort('Error: input SQL file missing.') if ARGV.empty?
abort('Error: choose --baseline or --oohj.') if options[:mode].nil?
abort('Error: -o/--output is required.')     if options[:output_pdf].nil?

hint =
  case options[:mode]
  when :baseline then '/*+ DISABLE_OPTIMISTIC_HASH_JOIN */'
  when :oohj     then '/*+ SET_OPTIMISM_FUNC(LINEAR) SET*
