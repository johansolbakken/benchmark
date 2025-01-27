require 'net/ftp'

# FTP server details
ftp_host = 'ftp.fu-berlin.de'
ftp_path = '/misc/movies/database/frozendata/'
destination_dir = './downloads'

# Ensure the destination directory exists
Dir.mkdir(destination_dir) unless Dir.exist?(destination_dir)

begin
  # Connect to the FTP server
  ftp = Net::FTP.new
  ftp.connect(ftp_host)
  ftp.login
  ftp.chdir(ftp_path)

  # List and filter .gz files
  files = ftp.nlst.select { |file| file.end_with?('.gz') }

  puts "Found #{files.size} .gz files to download."

  # Download each .gz file
  files.each do |file|
    local_file = File.join(destination_dir, file)
    puts "Downloading #{file}..."
    ftp.getbinaryfile(file, local_file)
    puts "Downloaded #{file} to #{local_file}"
  end

  # Close the FTP connection
  ftp.close
  puts 'All files downloaded successfully.'
rescue StandardError => e
  puts "An error occurred: #{e.message}"
ensure
  ftp.close if ftp && !ftp.closed?
end
