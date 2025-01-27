#!/usr/bin/env ruby

require 'fileutils'

# Path to the downloads directory
downloads_dir = './downloads'

begin
  if Dir.exist?(downloads_dir)
    puts "Deleting downloads folder and its contents..."
    FileUtils.rm_rf(downloads_dir)
    puts "Downloads folder removed successfully."
  else
    puts "Downloads folder does not exist, nothing to clean up."
  end
rescue StandardError => e
  puts "An error occurred while cleaning up: #{e.message}"
end
