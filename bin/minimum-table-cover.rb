#!/usr/bin/env ruby
require 'pg_query'
require 'set'

def extract_queries(c)
  c.split(';').map(&:strip).reject(&:empty?)
end

def extract_tables(q)
  PgQuery.parse(q).tables.map(&:downcase).uniq rescue (puts "Error parsing query: #{$!.message}"; [])
end

def minimum_table_cover(all, mapping)
  un = all.dup; sel = []
  until un.empty?
    t, qs = mapping.max_by { |_, qs| (qs & un).size }
    break if (qs & un).empty?
    sel << t; un.subtract(qs)
  end
  sel
end

def process_directory(dir)
  total = 0; mapping = Hash.new { |h, k| h[k] = Set.new }; all = Set.new
  Dir.entries(dir).grep(/^\d{1,2}.*[A-Za-z]\.sql$/i).each do |f|
    path = File.join(dir, f)
    content = File.read(path, encoding: 'UTF-8') rescue (puts "Error reading #{path}"; next)
    extract_queries(content).each_with_index do |q, i|
      id = "#{File.basename(f, '.sql')}_#{i+1}"
      total += 1; all.add(id)
      extract_tables(q).each { |t| mapping[t].add(id) }
    end
  end
  puts "\nSummary:\nTotal queries processed: #{total}\n\nTable Mapping (table => count):"
  mapping.sort.each { |t, qs| puts "#{t} => #{qs.size}" }
  cover = minimum_table_cover(all, mapping)
  puts "\nMinimum Table Cover: #{cover.join(', ')}"
end

if ARGV.length != 1
  puts "Usage: ruby #{__FILE__} <directory>"
  exit 1
end

process_directory(ARGV[0])
