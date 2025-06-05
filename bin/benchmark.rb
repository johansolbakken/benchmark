#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'yaml'
require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

CFG    = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CFG['user'], CFG['port'],
                           CFG['host'], CFG['name'], CFG['path'])

# ─────────  helper: inject hint into outer-most SELECT  ────
def inject_hint(sql, hint)
  depth = 0
  (0...sql.length).each do |i|
    depth += 1 if sql[i] == '('
    depth -= 1 if sql[i] == ')'
    if depth.zero? && sql[i, 6].casecmp('select').zero?
      return sql[0, i] + "SELECT #{hint} " + sql[i + 6..]
    end
  end
  sql.sub(/\bSELECT\b/i, "SELECT #{hint}")
end

# ───────────  helper: build EXPLAIN prefix safely  ─────────
def explain_prefix(o)
  flags = [:analyze, :tree, :json].select { |k| o[k] }
  if flags.length > 1
    puts Color.red('Choose only one of --analyze, --tree, --json')
    exit 1
  end
  return ''                     if flags.empty?
  return 'EXPLAIN ANALYZE '     if o[:analyze]
  return 'EXPLAIN FORMAT=TREE ' if o[:tree]
  return 'EXPLAIN FORMAT=JSON ' if o[:json]
  ''
end

# ────────────────  run a single SQL file  ─────────────────
def run_query_file(file, opt)
  unless File.exist?(file)
    puts Color.red("No such file: #{file}")
    exit 1
  end

  sql = File.read(file)
  sql.sub!(/;\s*\z/, '')        # strip ONE trailing semicolon
  sql = inject_hint(sql, opt[:hint]) if opt[:hint]

  CLIENT.run_query("#{explain_prefix(opt)}#{sql}")
rescue StandardError => e
  puts Color.red("Error: #{e.message}")
  exit 1
end

# ────────────────  misc helper actions  ───────────────────
def prepare_mysql
  CLIENT.run_file('./sql/experimental_setup.sql')
  CLIENT.run_file('./sql/analyze_tables.sql')
  puts Color.green('Prepared MySQL environment')
end
def setup_database = puts Color.yellow('--setup not implemented')
def feed_data      = puts Color.yellow('--feed  not implemented')

# ────────────────────────  CLI  ───────────────────────────
def parse_cli
  h = {}
  OptionParser.new do |o|
    o.banner = 'Usage: run_queries.rb [options]'
    o.on('--run FILE')          { |v| h[:query] = v }
    o.on('--prepare-mysql')     { h[:prepare] = true }
    o.on('--analyze')           { h[:analyze] = true }
    o.on('--tree')              { h[:tree] = true }
    o.on('--json')              { h[:json] = true }
    o.on('--hint HINT')         { |v| h[:hint] = v }
    o.on('--database DB')       { |v| h[:database] = v }
    o.on('--setup')             { h[:setup] = true }
    o.on('--feed')              { h[:feed] = true }
  end.parse!
  h
end

# ───────────────────────  dispatcher  ─────────────────────
def main
  o = parse_cli
  CLIENT.use_database(o[:database]) if o[:database]

  if    o[:setup]   then setup_database
  elsif o[:query]   then run_query_file(o[:query], o)
  elsif o[:feed]    then feed_data
  elsif o[:prepare] then prepare_mysql
  else
    puts Color.red('Nothing to do. Use --run, --prepare-mysql, etc.')
  end
end
main if __FILE__ == $PROGRAM_NAME
