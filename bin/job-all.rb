#!/usr/bin/env ruby

require 'fileutils'

INPUT_DIR  = './job-queries'
OUTPUT_DIR = './job-order-all-queries'

FileUtils.mkdir_p OUTPUT_DIR

Dir.glob(File.join(INPUT_DIR, '*')).each do |file_path|
  filename = File.basename(file_path)

  # Process only files matching the expected pattern (e.g. "123a.sql")
  unless filename =~ /^\d+[a-z]\.sql$/i
    puts "Skipping #{filename} – filename does not match pattern."
    next
  end

  content = File.read(file_path)

  # Replace the column list in the SELECT clause with a star (*)
  # This substitution looks for a pattern starting with SELECT,
  # followed by any columns, and then FROM.
  new_content = content.sub(/(select\s+)(.+?)(\s+from\b)/im) do
    "#{$1}*#{$3}"
  end

  if new_content.include?('cast_info')
    new_content = new_content.sub(/;\s*\z/, ' order by ci.id;')
  else
    new_content = new_content.sub(/;\s*\z/, ' order by t.id;')
  end

  # Write the modified content to the output folder.
  output_file = File.join(OUTPUT_DIR, filename)
  File.open(output_file, "w") { |f| f.write(new_content) }
  puts "Processed #{filename}."
end
