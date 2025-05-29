#!/usr/bin/env ruby

require 'optparse'
require 'open3'
require 'yaml'

require_relative '../lib/color'
require_relative '../lib/mysql'

CONFIG = YAML.load_file('config.yaml')['mysql']

SCALES = ['s1']

TABLES = %w[
  customer
  part
  supplier
  date
  lineorder
]

def feed_data(client, dataset_path)
  TABLES.each_with_index do |table, index|
    tbl_file = File.expand_path(File.join(dataset_path, "#{table}.tbl"))
    unless File.exist?(tbl_file)
      abort Color.red(".tbl file not found: #{tbl_file}")
    end

    puts Color.bold("(#{index + 1}/#{TABLES.size}) Loading table: #{table} from #{tbl_file}")
    load_sql = <<~SQL
      LOAD DATA LOCAL INFILE '#{tbl_file}' \
      INTO TABLE #{table} \
      FIELDS TERMINATED BY '|' \
      LINES TERMINATED BY '|\\n';
    SQL

    unless client.run_query(load_sql)
      abort Color.red("Failed to load data for table: #{table}")
    end
  end

  puts Color.green("\nAll SSB tables loaded for database #{client.db_name}!")
rescue StandardError => e
  abort Color.red("Error during data load: #{e.message}")
end

SCALES.each do |scale|
  db_name      = "ssb_#{scale}"
  dataset_path = "./ssb-#{scale}-dataset"

  puts Color.blue("\n==> Starting load for Scale Factor #{scale} (DB: #{db_name}) <==")
  unless Dir.exist?(dataset_path)
    abort Color.red("Dataset directory not found: #{dataset_path}")
  end

  client = MySQL::Client.new(
    CONFIG['user'],
    CONFIG['port'],
    CONFIG['host'],
    db_name,
    CONFIG['path']
  )

  feed_data(client, dataset_path)
end
