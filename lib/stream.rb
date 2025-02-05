# lib/stream.rb

require 'open3'

module Stream
  ##
  # Runs a shell command and streams STDOUT/STDERR in real-time.
  #
  # @param [String] command The shell command to execute.
  # @return [void]
  def self.run_command(command)
    puts "Executing: #{command}"

    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      threads = []

      # Stream STDOUT, converting literal "\n" sequences into actual newlines.
      threads << Thread.new do
        stdout.each_line { |line| puts line.chomp.gsub('\\n', "\n") }
      end

      # Stream STDERR, converting literal "\n" sequences into actual newlines.
      threads << Thread.new do
        stderr.each_line { |line| warn line.chomp.gsub('\\n', "\n") }
      end

      threads.each(&:join)

      exit_status = wait_thr.value
      unless exit_status.success?
        puts "Error: Command exited with status #{exit_status.exitstatus}"
        exit exit_status.exitstatus
      end
    end
  end

  ##
  # Runs a shell command, providing input via STDIN.
  #
  # @param [String] command The shell command to execute.
  # @param [String] input The string to write to STDIN.
  # @return [void]
  def self.run_command_with_input(command, input)
    puts "Executing: #{command} with input size: #{input.bytesize} bytes"

    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdin.write(input)
      stdin.close

      threads = []
      threads << Thread.new { stdout.each_line { |line| puts line.chomp.gsub('\\n', "\n") } }
      threads << Thread.new { stderr.each_line { |line| warn line.chomp.gsub('\\n', "\n") } }
      threads.each(&:join)

      exit_status = wait_thr.value
      unless exit_status.success?
        puts "Error: Command exited with status #{exit_status.exitstatus}"
        exit exit_status.exitstatus
      end
    end
  end
end
