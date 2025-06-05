#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'yaml'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

# ──────────────────────────  configuration  ────────────────────────────────
CFG           = YAML.load_file('config.yaml')['mysql']
CLIENT        = MySQL::Client.new(CFG['user'], CFG['port'], CFG['host'], CFG['name'], CFG['path'])

# ──────────────────────  helpers: hint injection  ──────────────────────────
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
  sql.sub(/\bSELECT\b/i, "SELECT #{hint}") # fallback
end

# ─────────────────────  helpers: EXPLAIN prefix  ───────────────────────────
def build_explain_prefix(opts)
  modes = [:explain, :tree, :json]
  active = modes.select { |m| opts[m] }
  if active.size > 1
    puts Color.red('Error: choose only one EXPLAIN variant.')
    exit 1
  end

  return '' if active.empty?
  return 'EXPLAIN ANALYZE '     if opts[:explain]
  return 'EXPLAIN FORMAT=TREE ' if opts[:tree]
  return 'EXPLAIN FORMAT=JSON ' if opts[:json]
  ''
end

# ───────────────────────  sub-command: run file  ───────────────────────────
def run_query_file(file, opts)
  unless File.exist?(file)
    puts Color.red("Query file not found: #{file}")
    exit 1
  end

  sql = File.read(file)
  sql.gsub!(/\s+/, ' ')   # compress whitespace
  sql.sub!(/;\s*\z/, '')  # strip trailing semicolon
  sql = inject_hint(sql, opts[:hint]) if opts[:hint]

  final_sql = "#{build_explain_prefix(opts)}#{sql}"
  CLIENT.run_query(final_sql)
rescue StandardError => e
  puts Color.red("Error while running query: #{e.message}")
  exit 1
end

# ──────────────────────  other helper actions  ─────────────────────────────
def prepare_mysql
  CLIENT.run_file('./sql/experimental_setup.sql')
  CLIENT.run_file('./sql/analyze_tables.sql')
  puts Color.green("\nPrepared MySQL environment")
end

def setup_database     = puts Color.yellow('setup_database not implemented')
def feed_data          = puts Color.yellow('feed_data not implemented')

# ───────────────────────────  CLI parsing  ─────────────────────────────────
def parse_options
  opts = {}
  OptionParser.new do |o|
    o.banner = 'Usage: run_queries.rb [options]'

    o.on('--run FILE',           'Run a SQL file')                      { |f| opts[:query]   = f }
    o.on('--prepare-mysql',      'Analyze & set costs')                 { opts[:prepare]     = true }

    o.on('--analyze',            'EXPLAIN ANALYZE')                     { opts[:explain]     = true }
    o.on('--tree',               'EXPLAIN FORMAT=TREE')                 { opts[:tree]        = true }
    o.on('--json',               'EXPLAIN FORMAT=JSON')                 { opts[:json]        = true }

    o.on('--hint HINT',          'SQL hint to inject')                  { |h| opts[:hint]    = h }
    o.on('--database DB',        'Override database')                   { |db| opts[:database] = db }

    o.on('--setup',              'Create schema (if implemented)')      { opts[:setup]       = true }
    o.on('--feed',               'Load CSV data (if implemented)')      { opts[:feed]        = true }
  end.parse!
  opts
end

# ────────────────────────────  dispatcher  ────────────────────────────────
def main
  opts = parse_options
  CLIENT.use_database(opts[:database]) if opts[:database]

  if opts[:setup]
    setup_database
  elsif opts[:query]
    run_query_file(opts[:query], opts)
  elsif opts[:feed]
    feed_data
  elsif opts[:prepare]
    prepare_mysql
  else
    puts Color.red('No valid action. Use --run, --prepare-mysql, etc.')
  end
end

main if __FILE__ == $PROGRAM_NAME
