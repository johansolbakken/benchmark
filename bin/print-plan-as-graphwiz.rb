#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'yaml'
require 'json'
require 'fileutils'
require_relative '../lib/mysql'

# ─────────────────────  configuration  ─────────────────────
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'],
                           CONFIG['host'], CONFIG['name'],
                           CONFIG['path'], true)

# ─────────  helper: inject hint into outer-most SELECT  ─────
def inject_hint(sql, hint)
  depth = 0
  (0...sql.length).each do |i|
    depth += 1 if sql[i] == '('
    depth -= 1 if sql[i] == ')'
    return sql[0, i] + "SELECT #{hint} " + sql[i + 6..] if depth.zero? && sql[i, 6].casecmp('select').zero?
  end
  sql.sub(/\bSELECT\b/i, "SELECT #{hint}") # fallback
end

# ─────────────  helper: JSON plan  →  GraphViz  ────────────
def json_to_dot(data, truncate)
  dot = ['digraph QueryPlan {',
         '  node [fontname="Helvetica" shape=none]',
         '  edge [arrowhead=none]']

  @node = 0
  short_map = {
    'Nested loop inner join' => 'NLJ',
    'Nested loop left join' => 'Outer NLJ',
    'Optimistic Hash Join' => 'OOHJ',
    'Optimistic Outer Hash Join' => 'Outer OOHJ',
    'Index lookup' => 'IDX',
    'Single-row index lookup' => '1IDX',
    'PRIMARY' => 'PRI',
    'Table scan' => 'TS',
    'Inner hash join' => 'HJ',
    'Left hash join' => 'Outer HJ'
  }

  walk = lambda do |node|
    cur = @node
    label = node['operation'] || 'Node'
    if node['was_optimistic_hash_join']
      label = label.gsub('Inner hash join',  'Optimistic Hash Join')
                   .gsub('Left hash join',   'Optimistic Outer Hash Join')
    end
    label = label.gsub('"', '\"')

    # ── NEW: shorten long filter predicates ───────────────────────────
    if label =~ /Filter:\s*(.+)\z/i
      cond = Regexp.last_match(1).strip
      if cond.length > 20
        cond = cond[0, 20] + '…'
        label = label.sub(/Filter:\s*.+\z/i, "Filter: #{cond}")
      end
    end

    # ── optional global truncation mode ───────────────────────────────
    if truncate
      label = label.gsub(/\(cost=[^)]+\)/, '').strip
      short_map.each { |k, v| label.gsub!(k, v) }
    end

    dot << %(  node#{cur} [label="#{label}"];)
    @node += 1

    if node['inputs'].is_a?(Array)
      node['inputs'].each do |child|
        cid = walk.call(child)
        dot << "  node#{cur} -> node#{cid};"
      end
    end
    cur
  end

  root = data['query_plan'] || data['query_block'] || data
  walk.call(root)
  dot << '}'
  dot.join("\n")
end

# ─────────────────────────  main  ──────────────────────────
def run(sql_file, pdf_out, hint, show_json, keep_dot, trunc, db)
  sql = File.read(sql_file)
  sql.sub!(/;\s*\z/, '')
  sql = inject_hint(sql, hint) unless hint.empty?
  CLIENT.use_database(db) if db

  plan_json, = CLIENT.run_query_get_stdout("EXPLAIN FORMAT=json #{sql}")
  plan_json.gsub!(/\\n/, '').sub!(/^EXPLAIN/, '')
  data = JSON.parse(plan_json)
  puts JSON.pretty_generate(data) if show_json

  dot_code = json_to_dot(data, trunc)
  File.write('query_plan.dot', dot_code)
  FileUtils.mkdir_p(File.dirname(pdf_out))
  system('dot', '-Tpdf', '-Gdpi=300', '-o', pdf_out, 'query_plan.dot')
  File.delete('query_plan.dot') unless keep_dot
  puts "PDF written to #{pdf_out}"
end

# ──────────────────────────  CLI  ─────────────────────────
opts = { show_json: false, keep_dot: false, truncate: false,
         mode: nil, output: nil, database: nil, func: 'LINEAR' }
OptionParser.new do |o|
  o.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options] input.sql"
  o.on('--baseline')          { opts[:mode] = :baseline }
  o.on('--oohj')              { opts[:mode] = :oohj }
  o.on('--database DB')       { |v| opts[:database] = v }
  o.on('-oFILE')              { |v| opts[:output] = v }
  o.on('--show-json')         { opts[:show_json] = true }
  o.on('-c', '--keep-dot')    { opts[:keep_dot] = true }
  o.on('--truncate')          { opts[:truncate] = true }
  o.on('--func FUNC', 'Optimism function name (used with --oohj)') do |v|
    opts[:func] = v
  end
end.order!
abort('input file missing')          if ARGV.empty?
abort('choose --baseline or --oohj') if opts[:mode].nil?
abort('use -o to name output')       if opts[:output].nil?

hint = case opts[:mode]
       when :baseline
         '/*+ DISABLE_OPTIMISTIC_HASH_JOIN */'
       when :oohj
         "/*+ SET_OPTIMISM_FUNC(#{opts[:func]}) SET_OPTIMISM_LEVEL(0.8) */"
       end

run(ARGV[0], opts[:output], hint, opts[:show_json],
    opts[:keep_dot], opts[:truncate], opts[:database])
