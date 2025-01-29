require 'fileutils'

require_relative 'lib/color'

TAR_URL = 'https://event.cwi.nl/da/job/imdb.tgz'
DESTINATION_DIR = './dataset'
TAR_FILE = File.join(DESTINATION_DIR, 'imdb.tgz')

if Dir.exist?(DESTINATION_DIR)
  delete_message = Color.bold("rm -rf #{destination_dir}")
  puts "#{Color.yellow("Aborting")}: #{DESTINATION_DIR} already exists. Run `#{delete_message}` to redownload."
  exit
else
  Dir.mkdir(DESTINATION_DIR)
  puts "Created directory: #{DESTINATION_DIR}"
end

# Use wget to download the tar file and pipe the output to stdout
puts "Downloading #{TAR_URL}..."
wget_command = "wget -O #{TAR_FILE} #{TAR_URL}"
system(wget_command)

# Extract the tar file
puts "Extracting #{TAR_FILE} into #{DESTINATION_DIR}..."
system("tar -xvzf #{TAR_FILE} -C #{DESTINATION_DIR}")

puts "Extraction completed."
