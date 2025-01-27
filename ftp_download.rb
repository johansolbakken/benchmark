require 'fileutils'

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

# Use wget to download the tar file and pipe the output to stdout
puts "Downloading #{tar_url}..."
wget_command = "wget -O #{tar_file} #{tar_url}"
system(wget_command)

# Extract the tar file
puts "Extracting #{tar_file} into #{destination_dir}..."
system("tar -xvzf #{tar_file} -C #{destination_dir}")

puts "Extraction completed."
