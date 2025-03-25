#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'
require 'csv'
require 'unicode_utils'
require 'i18n'

require_relative '../lib/byte'
require_relative '../lib/mysql'
require_relative '../lib/color'

CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

QUERIES_ON_DISK_FILE = './results/oohj-queries-on-disk.txt'
HINT = '/*+ SET_OPTIMISM_FUNC(SIGMOID) */'
HINT = '/*+ DISABLE_OPTIMISTIC_HASH_JOIN */'

I18n.config.available_locales = [:en]

def parse_options
  options = {
    analyze: false,
    compare: false,
    disable_optimistic: false,
    summary: false
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
  end.parse!

  if ARGV.empty?
    puts "Error: Missing mandatory INPUT_DIR argument."
    puts "Usage: #{$PROGRAM_NAME} [options] INPUT_DIR"
    exit 1
  end

  options[:input_dir] = ARGV.shift
  options
end

# Find queries that use optimistic hash join and go on disk and write names of those queries to a file
# def find_oohj_on_disk_queries(input_dir)
#   files_with_optimistic = []
#   files = Dir[File.join(input_dir, '*.sql')]
#   files.each_with_index do |file, index|
#     header = Color.bold("Processing #{index+1}/#{files.count}:")
#     puts "#{header} #{file}"
#     query = File.read(file).lines.map(&:strip).join(' ')
#     stdout, _stderr = CLIENT.run_query_get_stdout("EXPLAIN ANALYZE #{query}")
#     if stdout.include?('went_on_disk=true')
#       files_with_optimistic << file
#     end
#   end

#   puts "#{Color.bold('Caching analyzed results in:')} #{QUERIES_ON_DISK_FILE}"
#   file_path = QUERIES_ON_DISK_FILE
#   File.open(file_path, 'w') do |f|
#     files_with_optimistic.each do |file|
#       f.puts file
#     end
#   end
# end

# Run all queries that use optimistic hash join and go on disk and save the output to a file
# def run_queries_and_save_output(files_with_optimistic)
#   files_with_optimistic.each do |file|
#     query = File.read(file).lines.map(&:strip).join(' ')

#     if options[:disable_optimistic]
#       query = query.sub(/select\s+/i, "/*+ DISABLE_OPTIMISTIC_HASH_JOIN */")
#     end

#     stdout, _stderr = CLIENT.run_query_get_rows(query)
#     file_path = "./results/#{File.basename(file)}.csv"
#     CSV.open(file_path, 'w') do |csv|
#       stdout.each do |row|
#         csv << row
#       end
#     end
#   end
# end

def get_order_by_condition(file)
  query = File.read(file)
  order_by_condition = query.match(/order by (.*)/i)[1].gsub(";", "")
  order_by_condition 
end

# Normalize the string: remove accents, downcase, strip punctuation, handle numbers, remove leading quotes
def normalize_string(str)
  I18n.transliterate(str).downcase
end


# Check if the output of the queries is sorted
# def check_if_result_is_sorted_on_condition(file_name, condition)
#   rows = CSV.read(file_name)
#   header = rows.shift
#   column_index = header.index(condition)

#   rows.each_cons(2) do |row1, row2|
#     # Normalize both strings for comparison
#     normalized1 = normalize_string(row1[column_index])
#     normalized2 = normalize_string(row2[column_index])

#     if normalized1 > normalized2
#       puts "Row 1: #{row1}"
#       puts "Row 2: #{row2}"
#       return false
#     end
#   end
#   true
# end

def contains_order_by(file)
  query = File.read(file).lines.map(&:strip).join(' ')
  !!(query =~ /order\s+by/i)
end

def count_oohj(file)
  query = File.read(file).lines.map(&:strip).join(' ')
  query = query.gsub(/select/i, "select #{HINT}")
  query = "EXPLAIN FORMAT=TREE #{query}"
  stdout, stderr, ok = CLIENT.run_query_get_stdout(query)

  unless ok
    puts Color.red('Error running query.')
    puts stderr
    return 0
  end

  stdout.scan(/optimistic hash join/i).size
end

def count_went_on_disk_true(file)
  query = File.read(file).lines.map(&:strip).join(' ')
  query = query.gsub(/select/i, "select #{HINT}")
  query = "EXPLAIN ANALYZE #{query}"

  stdout, stderr, ok = CLIENT.run_query_get_stdout(query)
  unless ok
    puts Color.red('Error running query.')
    puts stderr
    return 0
  end

  stdout.scan(/went_on_disk=true/i).size
end

def check_sorting(file)
  query = File.read(file).lines.map(&:strip).join(' ')
  query = query.gsub(/select/i, "select #{HINT}")
  stdout, stderr, ok = CLIENT.run_query_get_stdout(query)
  unless ok
    puts Color.red('Error running query during sort check.')
    puts stderr
    return false
  end

  lines = stdout.split("\n")
  if lines.empty?
    puts "  No output returned for file #{file}"
    return false
  end

  result = lines.map { |line| line.split("\t") }
  header = result.first
  if header.nil? || header.empty?
    puts "  No header row found for file #{file}"
    return false
  end

  order_condition = get_order_by_condition(file)
  order_index = header.find_index { |col| normalize_string(col) == normalize_string(order_condition) }
  if order_index.nil?
    puts "  Failed to find index of order by column '#{order_condition}' in header: #{header.inspect}"
    return false
  end

  order_values = result[1..-1].map { |row| row[order_index] }
  normalized_values = order_values.map { |value| normalize_string(value) }

  if normalized_values == normalized_values.sort
    puts "  The column '#{order_condition}' is sorted."
    return true
  else
    puts "  The column '#{order_condition}' is not sorted."
    return false
  end
end


# Run the script
def run()
  options = parse_options
  input_dir = options[:input_dir]

  if options[:join_buffer_size]
    buffer_size = Byte.parse(options[:join_buffer_size])
    CLIENT.run_query_get_stdout("SET GLOBAL join_buffer_size = #{buffer_size}")
  end

  files = Dir[File.join(input_dir, '*.sql')]
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

    query[:optimistic_count] = count_oohj(query[:file])
    if query[:optimistic_count] <= 0
      puts '  OOHJ count was 0.'
    end

    if options[:analyze]
      query[:spill_count] = count_went_on_disk_true(query[:file])
      puts "  Spill count: #{query[:spill_count]}"
    end

    if options[:compare]
      query[:was_sorted] = check_sorting(query[:file])
      puts "  Was sorted: #{query[:was_sorted]}"
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


  # files.each_with_index do |file, index|
  #   header = Color.bold("Processing #{index+1}/#{files.count}:")
  #   puts "#{header} #{file}"
  #   end

  # if options[:compare]
  #   puts Color.bold('Running the queries and saving the output to a file...')
  #   files_with_optimistic = File.readlines(QUERIES_ON_DISK_FILE).map(&:strip)
  #   run_queries_and_save_output(files_with_optimistic)

  #   files_with_optimistic = File.readlines(QUERIES_ON_DISK_FILE).map(&:strip)

  #   files_with_optimistic.each do |file|
  #     query_name = File.basename(file, '.sql')
  #     order_by_condition = get_order_by_condition(query_name, input_dir)
  #     csv_file_path = "./results/#{query_name}.sql.csv"
  #     puts "Order by condition for query #{query_name}: #{order_by_condition}"

  #     if File.exist?(csv_file_path)
  #       is_sorted = check_if_result_is_sorted_on_condition(csv_file_path, order_by_condition)
  #       puts "Query #{query_name}: Result is #{is_sorted ? 'sorted' : 'not sorted'} on condition '#{order_by_condition}'."
  #     else
  #       puts "CSV file for query #{query_name} not found. Skipping."
  #     end
  #   end
  # end
end

run()
