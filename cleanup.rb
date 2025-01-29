#!/usr/bin/env ruby

require 'fileutils'

require_relative 'lib/color'

DATASET_DIR = './dataset'

begin
  if Dir.exist?(DATASET_DIR)
    puts "Deleting downloads folder and its contents..."
    FileUtils.rm_rf(DATASET_DIR)
    puts Color.green("\nDownloads folder removed successfully.")
  else
    puts "Downloads folder does not exist, nothing to clean up."
  end
rescue StandardError => e
  puts Color.red("An error occurred while cleaning up: #{e.message}")
end
