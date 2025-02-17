#!/usr/bin/env ruby
require 'fileutils'

# Set your source and output folder paths here
SOURCE_FOLDER = './job'
OUTPUT_FOLDER = './job-queries'

# Create output folder if it doesn't exist
FileUtils.mkdir_p(OUTPUT_FOLDER)

# Regex to match filenames that start with a number and end with a letter before the extension
filename_regex = /\A\d.*[A-Za-z]\.sql\z/

# Process each SQL file in the source folder that matches the filename pattern
Dir.glob(File.join(SOURCE_FOLDER, '*.sql')).select { |file_path|
  File.basename(file_path) =~ filename_regex
}.each do |file_path|
  content = File.read(file_path)

  # Replace every instance of MIN(schema.table) or MIN(table) with just schema.table or table
  new_content = content.gsub(/MIN\(\s*([\w\.]+)\s*\)/i, '\1')
  
  # Rename alias 'character' to 'character_name'
  new_content = new_content.gsub(/\bcharacter\b/, 'character_name')

  # Determine the output file path (same filename in output folder)
  output_file = File.join(OUTPUT_FOLDER, File.basename(file_path))

  # Write the modified content to the output file
  File.write(output_file, new_content)
  puts "Processed #{file_path} -> #{output_file}"
end

