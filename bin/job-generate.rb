#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'

# Parse command-line options for output directory
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-oDIR", "--output=DIR", "Output directory to write join query file") do |dir|
    options[:output_dir] = dir
  end
end.parse!

if options[:output_dir].nil? || options[:output_dir].strip.empty?
  abort "Output directory is required. Use -o or --output to specify the directory."
end

# Create the output directory if it doesn't exist
FileUtils.mkdir_p(options[:output_dir])

JOIN_COUNT = 15
ORDER_BY = 'ORDER BY cast_info.id;'

# Total order of joinable tables with "title" first
total_order = [
  "title",          # 1. Central movie table
  "cast_info",      # 3. Joins to title on movie_id
  "name",           # 17. Joins from cast_info (or complete_cast) via person_id
  "role_type",      # 11. Joins from cast_info via cast_info.role_id = role_type.id
  "movie_info",     # 4. Joins to title on movie_id
  "movie_keyword",  # 6. Joins to title on movie_id
  "movie_link",     # 7. Joins to title on movie_id
  "movie_companies",# 8. Joins to title on movie_id
  "complete_cast",  # 9. Joins to title on movie_id
  "kind_type",      # 10. Joins from title via title.kind_id = kind_type.id
  "info_type",      # 12. Joins from movie_info (or movie_info_idx) via info_type_id
  "keyword",        # 13. Joins from movie_keyword via movie_keyword.keyword_id = keyword.id
  "link_type",      # 14. Joins from movie_link via movie_link.link_type_id = link_type.id
  "company_name",   # 15. Joins from movie_companies via movie_companies.company_id = company_name.id
  "company_type",   # 16. Joins from movie_companies via movie_companies.company_type_id = company_type.id
  "person_info"     # 19. Joins to name via name.id = person_info.person_id
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

for i in 2..JOIN_COUNT
  table_count = i + 1

  # Select the first TABLE_COUNT tables from total_order
  tables_to_join = total_order[0...table_count]

  # Build the join query based on tables_to_join and join_conditions.
  # For each table (after the first) we find a parent in the already-joined tables that provides a join condition.
  join_query = "SELECT * FROM #{tables_to_join.first}"
  joined_tables = [tables_to_join.first]

  tables_to_join[1..-1].each do |tbl|
    parent = joined_tables.find { |p| join_conditions[p] && join_conditions[p].key?(tbl) }
    if parent
      condition = join_conditions[parent][tbl]
      join_query += " JOIN #{tbl} ON #{condition}"
      joined_tables << tbl
    else
      abort "No join condition found for table #{tbl} with any of the joined tables: #{joined_tables.join(', ')}"
    end
  end

  join_query += " #{ORDER_BY}"

  # Write the join query to a file in the output directory
  output_file = File.join(options[:output_dir], "q_J#{i}.sql")
  File.write(output_file, join_query)

  puts "Join query written to #{output_file}"

end
