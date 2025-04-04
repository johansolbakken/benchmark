#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'

require_relative '../lib/byte'
require_relative '../lib/mysql'
require_relative '../lib/color'

CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

QUERIES_ON_DISK_FILE = './results/oohj-queries-on-disk.txt'

def parse_options
  options = {
    analyze: false,
    compare: false,
    disable_optimistic: false,
    summary: false,
    small: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] INPUT_DIR"
    opts.on('--join-buffer-size SIZE', 'Set join buffer size') do |size|
      options[:join_buffer_size] = size
    end
    opts.on('--analyze', 'Runs EXPLAIN ANALYZE and finds went_on_disk=true') do
      options[:analyze] = true
    end
    opts.on('--compare', 'Check if cached txt file is sorted') do
      options[:compare] = true
    end
    opts.on('--disable', 'Disable OOHJ') do
      options[:disable_optimistic] = true
    end
    opts.on('--summary', 'Display summary at end of execution') do
      options[:summary] = true
    end
    opts.on('--small', 'Debug: limit amount of queries to test') do
      options[:small] = true
    end
  end.parse!

  if ARGV.empty?
    puts "Error: Missing mandatory INPUT_DIR argument."
    puts "Usage: #{$PROGRAM_NAME} [options] INPUT_DIR"
    exit 1
  end

  options[:input_dir] = ARGV.shift
  options
end

def get_order_by_condition(file)
  query = File.read(file)
  order_by_condition = query.match(/order by (.*)/i)[1].gsub(";", "").strip
  order_by_condition
end

def add_hint(query, disable)
  hint = '/*+ SET_OPTIMISM_FUNC(SIGMOID) */'
  if disable
    hint = '/*+ DISABLE_OPTIMISTIC_HASH_JOIN */'
  end
  query.gsub(/select/i, "select #{hint}")
end

def contains_order_by(file)
  query = File.read(file).lines.map(&:strip).join(' ')
  !!(query =~ /order\s+by/i)
end

def count_oohj(file, disable)
  query = File.read(file).lines.map(&:strip).join(' ')
  query = add_hint(query, disable)
  # query = query.gsub(/order by/i, 'order by binary')
  query = "EXPLAIN FORMAT=TREE #{query}"
  stdout, stderr, ok = CLIENT.run_query_get_stdout(query)

  unless ok
    puts Color.red('Error running query.')
    puts stderr
    return 0
  end

  stdout.scan(/optimistic hash join/i).size
end

def count_went_on_disk_true(file, disable)
  query = File.read(file).lines.map(&:strip).join(' ')
  query = add_hint(query, disable)
  # query = query.gsub(/order by/i, 'order by binary')
  query = "EXPLAIN ANALYZE #{query}"

  stdout, stderr, ok = CLIENT.run_query_get_stdout(query)
  unless ok
    puts Color.red('Error running query.')
    puts stderr
    return 0
  end

  stdout.scan(/went_on_disk=true/i).size
end

def check_sorting(file, disable)
  query = File.read(file).lines.map(&:strip).join(' ')
  query = add_hint(query, disable)
  # query = query.gsub(/order by/i, 'order by binary')
  stdout, stderr, ok = CLIENT.run_query_get_stdout(query)
  unless ok
    puts Color.red('Error running query during sort check.')
    puts stderr
    return false
  end

  lines = stdout.split("\n")
  if lines.empty?
    puts "  No output returned for file #{file}"
    return true
  end

  result = lines.map { |line| line.split("\t") }
  header = result.first
  if header.nil? || header.empty?
    puts "  No header row found for file #{file}"
    return false
  end

  order_condition = get_order_by_condition(file)
  order_index = header.find_index { |col| col == order_condition }
  if order_index.nil?
    puts "  Failed to find index of order by column '#{order_condition}' in header: #{header.inspect}"
    return false
  end

  order_values = result[1..-1].map { |row| row[order_index] }
  normalized_values = order_values.map { |value| value }

  if normalized_values == normalized_values.sort
    puts "  The column '#{order_condition}' is sorted."
    return true
  else
    puts "  The column '#{order_condition}' is not sorted."
    return false
  end
end

def run()
  options = parse_options
  input_dir = options[:input_dir]

  if options[:join_buffer_size]
    buffer_size = Byte.parse(options[:join_buffer_size])
    CLIENT.run_query_get_stdout("SET GLOBAL join_buffer_size = #{buffer_size}")
  end

  if File.directory?(input_dir)
    files = Dir[File.join(input_dir, '*.sql')]
  elsif File.file?(input_dir) && File.extname(input_dir) == '.sql'
    files = [input_dir]
  else
    puts 'Error: INPUT_DIR must be a directory containing .sql files or a single .sql file.'
    exit 1
  end

  if options[:small]
    files = files[0..0]
  end

  queries = files.map do |file|
    {
      file: file,
      spill_count: 0,
      optimistic_count: 0,
      was_sorted: false,
      contained_order_by: false,
    }
  end

  queries.each_with_index do |query, index|
    header = Color.bold("Processing: #{index+1}/#{queries.count}:")
    puts "#{header} #{query[:file]}"

    query[:contained_order_by] = contains_order_by(query[:file])
    if !query[:contained_order_by]
      puts '  Did not contain ORDER BY.'
      next
    end

    query[:optimistic_count] = count_oohj(query[:file], options[:disable_optimistic])
    if query[:optimistic_count] <= 0
      puts '  OOHJ count was 0.'
    else
      puts "  OOHJ count: #{query[:optimistic_count]}"
    end

    if options[:analyze]
      query[:spill_count] = count_went_on_disk_true(query[:file], options[:disable_optimistic])
      puts "  Spill count: #{query[:spill_count]}"
    end

    if options[:compare]
      query[:was_sorted] = check_sorting(query[:file], options[:disable_optimistic])
      sort_text = Color.red('false')
      if query[:was_sorted]
        sort_text = Color.green('true')
      end
      puts "  Was sorted: #{sort_text}"
    end
  end

  if options[:summary]
    rows = queries.map do |q|
      [
        File.basename(q[:file]),
        q[:contained_order_by] ? "Yes" : "No",
        q[:optimistic_count],
        q[:spill_count],
        q.key?(:was_sorted) ? (q[:was_sorted] ? "Yes" : "No") : "N/A"
      ]
    end

    table = Terminal::Table.new(
      title: "Query Summary",
      headings: ['Query', 'Contains ORDER BY', 'OOHJ Count', 'Spill Count', 'Sorted?'],
      rows: rows
    )

    puts table
  end

  puts Color.green('Successfully terminated!')
end

run()
