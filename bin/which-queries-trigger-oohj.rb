#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'terminal-table'

require_relative '../lib/mysql'

# Load MySQL configuration
CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

def create_hints(options)
  if options[:func]
    if options[:func] == 'DISABLED'
      return ' /*+ DISABLE_OPTIMISTIC_HASH_JOIN */'
    else
      return " /*+ SET_OPTIMISM_FUNC(#{options[:func]}) SET_OPTIMISM_LEVEL(#{options[:level]})*/"
    end
  end
  ''
end

# Count join occurrences in SQL queries from the job-queries directory
def count_optimistic(options)
  hints = create_hints(options)

  files_with_optimistic = []
  Dir['./job-order-queries/*.sql'].each do |file|
    query = File.read(file).lines.map(&:strip).join(' ')
    stdout, _stderr = CLIENT.run_query_get_stdout("EXPLAIN FORMAT=tree #{hints} #{query}")
    join_count = stdout.scan(/optimistic/i).size
    if join_count > 0
      files_with_optimistic << file
    end
  end
  return files_with_optimistic.sort
end

def output_file_name(options)
  postfix = ''
  if options[:func]
    if options[:func] == 'DISABLED'
      postfix = '-disabled'
    elsif options[:func] != ''
      postfix = "-#{options[:func]}-#{options[:level].to_s.gsub('.', '_')}"
    end
  end
  "oohj-queries#{postfix}.txt"
end

def run(options)
  files_with_optimistic = count_optimistic(options)
  file_name = output_file_name(options)
  file_path = "./results/#{file_name}"
  File.open(file_path, 'w') do |f|
    files_with_optimistic.each do |file|
      f.puts File.basename(file, '.*')
    end
  end
  puts "Successfully written to #{file_path}"
end

options = {}
OptionParser.new do |opts|
  opts.on('--func FUNCTION', 'Specify function to run') do |f|
    options[:func] = f
  end
  opts.on('--level LEVEL', Float, 'Specify optimism level.') do |l|
    options[:level] = l
  end
end.parse!

if options[:func] && options[:func] != 'DISABLED' && !options[:level]
  abort('If --func is specified and not equalt to DISABLED, --level must be specified')
end

puts(options)

run(options) if __FILE__ == $PROGRAM_NAME
