#!/usr/bin/env ruby

require 'optparse'
require 'yaml'

require_relative '../lib/sql_table_topological_sort'
require_relative '../lib/color'
require_relative '../lib/mysql'

# Configuration
CONFIG = YAML.load_file('config.yaml')['mysql']

def make_client(db)
  MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], db, CONFIG['path'])
end

# Set up the database using provided SQL files
def analyze_job
  client = make_client('imdbload')
  puts Color.bold('Analyzing imdbload tables')
  unless client.run_file('./sql/analyze_job.sql')
    abort Color.red("Failed to drop database #{DB_NAME}")
  end
end

def run(opts)
  analyze_job if opts[:job]
end

opts = {}
OptionParser.new do |op|
  op.banner = "Usage: #{File.basename($0)} [options]"
  op.on('--job', 'Analyze Join Order Benchmark tables.') { opts[:job] = true }
end.parse!

run(opts) if __FILE__ == $PROGRAM_NAME
