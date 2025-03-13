#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'

# Parse command-line options for output directory
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-oDIR", "--output=DIR", "Output directory to write query files") do |dir|
    options[:output_dir] = dir
  end
end.parse!

if options[:output_dir].nil? || options[:output_dir].strip.empty?
  abort "Output directory is required. Use -o or --output to specify the directory."
end

# Create the output directory if it doesn't exist
FileUtils.mkdir_p(options[:output_dir])

JOIN_COUNT = 15

# Array of where clause counts to generate.
where_counts = [1, 2, 4, 6, 8]
order_bys = {
  ID: 'ORDER BY cast_info.id;',
  TITLE: 'ORDER BY title.title;',
}

# Total order of joinable tables with "title" first.
total_order = [
  "title",          # 1. Central movie table
  "cast_info",      # 2. Joins to title on movie_id
  "name",           # 3. Joins via cast_info.person_id
  "role_type",      # 4. Joins via cast_info.role_id
  "movie_info",     # 5. Joins to title on movie_id
  "movie_keyword",  # 6. Joins to title on movie_id
  "movie_link",     # 7. Joins to title on movie_id
  "movie_companies",# 8. Joins to title on movie_id
  "complete_cast",  # 9. Joins to title on movie_id
  "kind_type",      # 10. Joins from title via title.kind_id
  "info_type",      # 11. Joins from movie_info via info_type_id
  "keyword",        # 12. Joins via movie_keyword (lookup)
  "link_type",      # 13. Joins via movie_link (lookup)
  "company_name",   # 14. Joins from movie_companies via company_id
  "company_type",   # 15. Joins from movie_companies via company_type_id
  "person_info"     # 16. Joins via name (person_info)
]

# Map of join conditions (parent -> { child -> condition })
join_conditions = {
  "title" => {
    "aka_title"      => "title.id = aka_title.movie_id",
    "cast_info"      => "title.id = cast_info.movie_id",
    "movie_info"     => "title.id = movie_info.movie_id",
    "movie_info_idx" => "title.id = movie_info_idx.movie_id",
    "movie_keyword"  => "title.id = movie_keyword.movie_id",
    "movie_link"     => "title.id = movie_link.movie_id",
    "movie_companies"=> "title.id = movie_companies.movie_id",
    "complete_cast"  => "title.id = complete_cast.movie_id",
    "kind_type"      => "title.kind_id = kind_type.id"
  },
  "cast_info" => {
    "role_type" => "cast_info.role_id = role_type.id",
    "name"      => "cast_info.person_id = name.id"
  },
  "movie_info" => {
    "info_type" => "movie_info.info_type_id = info_type.id"
  },
  "movie_info_idx" => {
    "info_type" => "movie_info_idx.info_type_id = info_type.id"
  },
  "movie_keyword" => {
    "keyword"   => "movie_keyword.keyword_id = keyword.id"
  },
  "movie_link" => {
    "link_type" => "movie_link.link_type_id = link_type.id"
  },
  "movie_companies" => {
    "company_name" => "movie_companies.company_id = company_name.id",
    "company_type" => "movie_companies.company_type_id = company_type.id"
  },
  "name" => {
    "aka_name"    => "name.id = aka_name.person_id",
    "person_info" => "name.id = person_info.person_id"
  }
}

# Map of example where conditions for each table, using non-id fields.
table_conditions = {
  "title"           => "(title.title LIKE '%Matrix%' OR title.title LIKE '%Marvel%')",
  "cast_info"       => "cast_info.note LIKE '%hero%'",
  "name"            => "name.name LIKE 'Keanu%'",
  "role_type"       => "role_type.role = 'Lead'",
  "movie_info"      => "movie_info.info LIKE '%Director%'",
  "movie_keyword"   => "movie_keyword.id > 10",  # invented column
  "movie_link"      => "movie_link.id > 10",        # invented column
  "movie_companies" => "movie_companies.note LIKE '%studio%'",
  "complete_cast"   => "complete_cast.status_code = 'active'",   # invented column
  "kind_type"       => "kind_type.kind = 'Feature'",
  "info_type"       => "info_type.info = 'Plot'",
  "keyword"         => "keyword.keyword = 'action'",
  "link_type"       => "link_type.link = 'sequel'",
  "company_name"    => "company_name.name LIKE '%Warner%'",
  "company_type"    => "company_type.kind = 'Production'",
  "person_info"     => "person_info.info LIKE '%bio%'"
}

# For each join count (from 2 up to JOIN_COUNT), generate a base join query
for i in 2..JOIN_COUNT
  table_count = i + 1
  # Select the first 'table_count' tables from total_order.
  tables_to_join = total_order[0...table_count]

  # Build the join query based on tables_to_join and join_conditions.
  base_query = "SELECT * FROM #{tables_to_join.first}"
  joined_tables = [tables_to_join.first]

  tables_to_join[1..-1].each do |tbl|
    parent = joined_tables.find { |p| join_conditions[p] && join_conditions[p].key?(tbl) }
    if parent
      condition = join_conditions[parent][tbl]
      base_query += " JOIN #{tbl} ON #{condition}"
      joined_tables << tbl
    else
      abort "No join condition found for table #{tbl} with any of the joined tables: #{joined_tables.join(', ')}"
    end
  end

  where_conditions = tables_to_join.map { |t| table_conditions[t] }

  where_counts.each do |wc|
    next if wc > where_conditions.length  # Skip if not enough tables.

    query = base_query.dup
    if wc > 0
      query += " WHERE " + where_conditions[0...wc].join(" AND ")
    end

    for k,v in order_bys
      out_query = "#{query} #{v}"

      output_file = File.join(options[:output_dir], "QJ#{i}A#{wc}#{k}.sql")
      File.write(output_file, out_query)
      puts "Query written to #{output_file}"
    end
  end
end
