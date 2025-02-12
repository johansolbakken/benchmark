
#!/usr/bin/env ruby
require 'fileutils'

# Save the original directory (where the script was started)
original_dir = Dir.pwd

# Step 0: Create required directories in the original working directory
directories = ['tpc-h-queries', 'tpc-h-ddl', 'tpc-h-dataset']
directories.each do |dir|
  target_dir = File.join(original_dir, dir)
  unless Dir.exist?(target_dir)
    puts "Creating directory: #{target_dir}"
    FileUtils.mkdir_p(target_dir)
  end
end

# Step 1: Change directory to tpc-h/dbgen (relative to the original directory)
dbgen_path = File.join(original_dir, "tpc-h", "dbgen")
begin
  Dir.chdir(dbgen_path)
rescue Errno::ENOENT
  puts "Error: Directory '#{dbgen_path}' not found."
  exit 1
end

# Step 2: Check if a makefile exists (check both "makefile" and "Makefile")
unless File.exist?("makefile") || File.exist?("Makefile")
  puts "Error: makefile not found in #{Dir.pwd}. Please create it and run this script again."
  exit 1
end

# Step 3: Build the project using make -j9
puts "Running 'make -j9'..."
unless system("make -j9")
  puts "Error: 'make -j9' command failed."
  exit 1
end

# Step 4: Run the data generator
puts "Running './dbgen -f -s 1'..."
unless system("./dbgen -f -s 1")
  puts "Error: './dbgen -f -s 1' command failed."
  exit 1
end

# Step 5: Set the DSS_QUERY environment variable
ENV['DSS_QUERY'] = "/src/tpc-h/dbgen/queries"
puts "Environment variable DSS_QUERY set to: #{ENV['DSS_QUERY']}"

# Step 6: Loop to generate query files (queries 1 to 22) in tpc-h-queries directory
(1..22).each do |i|
  # Build the output file path inside the tpc-h-queries directory
  output_file = File.join(original_dir, "tpc-h-queries", "q#{i}.sql")
  command = "./qgen -v -c -s 1 #{i} > #{output_file}"
  puts "Running '#{command}'..."
  unless system(command)
    puts "Error: Command '#{command}' failed."
    exit 1
  end
end

# Step 7: Copy all *.tbl files into tpc-h-dataset
tbl_files = Dir.glob("*.tbl")
if tbl_files.empty?
  puts "No .tbl files found to copy."
else
  dataset_dir = File.join(original_dir, "tpc-h-dataset")
  puts "Copying .tbl files to #{dataset_dir}..."
  tbl_files.each do |file|
    FileUtils.cp(file, dataset_dir)
  end
end

# Step 8: Copy all *.ddl files into tpc-h-ddl
ddl_files = Dir.glob("*.ddl")
if ddl_files.empty?
  puts "No .ddl files found to copy."
else
  ddl_dir = File.join(original_dir, "tpc-h-ddl")
  puts "Copying .ddl files to #{ddl_dir}..."
  ddl_files.each do |file|
    FileUtils.cp(file, ddl_dir)
  end
end

puts "All tasks completed successfully."

