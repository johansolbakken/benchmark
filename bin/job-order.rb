#!/usr/bin/env ruby
require 'fileutils'

INPUT_DIR  = './job-queries'
OUTPUT_DIR = './job-order-queries'
SKIPLIST = ["10b.sql", "10c.sql"] #failing for some reason

# Create the output folder if it doesn't exist.
FileUtils.mkdir_p OUTPUT_DIR

# Process only files with names like "1a.sql", "2B.sql", etc.
Dir.glob(File.join(INPUT_DIR, '*')).each do |file_path|
  filename = File.basename(file_path)

  if SKIPLIST.include?(filename)
    puts "Skipping #{filename} – file is in the SKIPLIST."
    next
  end

  unless filename =~ /^\d+[a-z]\.sql$/i
    puts "Skipping #{filename} – filename does not match pattern."
    next
  end

  content = File.read(file_path)

  # We need to find, scanning from the beginning of the file,
  # the first occurrence of either:
  #  - "as" followed by a word (our alias), or
  #  - "from"
  #
  # If "from" occurs first (or there is no "as ..."), then we skip the file.
  #
  # This regular expression uses a non-capturing group for "from" and a named capture for the alias:
  pattern = /\b(?:as\s+(?<alias>\w+)|from)\b/i

  match_data = content.match(pattern)
  if match_data.nil?
    puts "Skipping #{filename} – neither 'as' nor 'from' found."
    next
  end

  # If the first match is "from" (i.e. no alias captured), skip the file.
  if match_data[0].downcase == "from" || match_data[:alias].nil?
    puts "Skipping #{filename} – 'from' found before any valid 'as <alias>'."
    next
  end

  alias_name = match_data[:alias]
  puts "Processing #{filename} using alias '#{alias_name}'."

  # Replace the semicolon at the end of the file (and any trailing whitespace)
  # with " order by alias;"
  new_content = content.sub(/;\s*$/, " order by #{alias_name};")

  # Write the modified content to the output folder.
  output_file = File.join(OUTPUT_DIR, filename)
  File.open(output_file, "w") { |f| f.write(new_content) }
end

