#!/usr/bin/env ruby

require 'yaml'

require_relative '../lib/byte'
require_relative '../lib/mysql'
require_relative '../lib/color'

CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], CONFIG['name'], CONFIG['path'], silent=true)

def parse_options
  options = {}

  if ARGV.empty?
    puts 'Error: Missing mandatory INPUT_DIR argument.'
    puts "Usage: #{$PROGRAM_NAME} [options] SIZE"
    exit 1
  end

  options[:join_buffer_size] = ARGV.shift
  options
end

def run
  options = parse_options

  buffer_size = Byte.parse(options[:join_buffer_size])
  stdout, stderr, ok = CLIENT.run_query_get_stdout("SET GLOBAL join_buffer_size = #{buffer_size}")

  unless ok
    puts Color.bold('Stdout:')
    puts stdout
    puts Color.bold('Stderr:')
    puts stderr
    abort
  end

  puts Color.green('Successfully terminated!')
end

run
