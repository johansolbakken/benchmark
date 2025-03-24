#!/usr/bin/env ruby

require 'yaml'

require_relative '../lib/mysql'
require_relative '../lib/color'

CONFIG = YAML.load_file('config.yaml')['mysql']
CLIENT = MySQL::Client.new(CONFIG['user'], CONFIG['port'], CONFIG['host'], 'imdbload', CONFIG['path'], true)

def warmup_job
  job_tables = [
    'aka_name',
    'aka_title',
    'cast_info',
    'char_name',
    'comp_cast_type',
    'company_name',
    'company_type',
    'complete_cast',
    'info_type',
    'keyword',
    'kind_type',
    'link_type',
    'movie_companies',
    'movie_info',
    'movie_info_idx',
    'movie_keyword',
    'movie_link',
    'name',
    'person_info',
    'role_type',
    'title'
  ]

  job_tables.each_with_index do |table, index|
    query = "SELECT * FROM #{table}"
    header = Color.bold("Loading table #{index+1}/#{job_tables.count}:")
    puts "#{header} #{query}"
    _stdout, stderr, ok = CLIENT.run_query_get_stdout(query)
    if !ok
      puts stderr
    end
  end
end

warmup_job
