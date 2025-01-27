require 'fileutils'
require 'open-uri'

# Variables
tar_url = 'https://event.cwi.nl/da/job/imdb.tgz'
destination_dir = './downloads'
tar_file = File.join(destination_dir, 'imdb.tgz')

# Check if the destination directory exists
if Dir.exist?(destination_dir)
  puts "Aborting: #{destination_dir} already exists. Run `rm -rf #{destination_dir}` to redownload."
  exit
else
  # Create the destination directory
  Dir.mkdir(destination_dir)
  puts "Created directory: #{destination_dir}"
end

# Download the tar file
puts "Downloading #{tar_url} into #{tar_file}..."
open(tar_url) do |file|
  File.open(tar_file, 'wb') do |output|
    output.write(file.read)
  end
end
puts "Download completed."

# Extract the tar file
puts "Extracting #{tar_file} into #{destination_dir}..."
system("tar -xvzf #{tar_file} -C #{destination_dir}")

puts "Extraction completed."
