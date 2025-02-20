# lib/stream.rb

require 'open3'

module Stream
  ##
  # Runs a shell command and streams STDOUT/STDERR in real-time.
  #
  # @param [String] command The shell command to execute.
  # @return [Array(String, String, Process::Status)] A tuple containing the STDOUT output,
  #   STDERR output, and the exit status of the command.
  def self.run_command(command)
    puts "Executing: #{command}"

    stdout_str = ""
    stderr_str = ""

    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      threads = []
      threads << Thread.new do
        stdout.each_line do |line|
          formatted_line = line.chomp.gsub('\\n', "\n")
          puts formatted_line
          stdout_str << line
        end
      end

      threads << Thread.new do
        stderr.each_line do |line|
          formatted_line = line.chomp.gsub('\\n', "\n")
          warn formatted_line
          stderr_str << line
        end
      end

      threads.each(&:join)

      exit_status = wait_thr.value
      return stdout_str, stderr_str, exit_status
    end
  end

  ##
  # Runs a shell command, providing input via STDIN.
  #
  # @param [String] command The shell command to execute.
  # @param [String] input The string to write to STDIN.
  # @return [Array(String, String, Process::Status)] A tuple containing the STDOUT output,
  #   STDERR output, and the exit status of the command.
  def self.run_command_with_input(command, input, silent=false)
    puts "Executing: #{command} with input size: #{input.bytesize} bytes"

    stdout_str = ""
    stderr_str = ""

    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdin.write(input)
      stdin.close

      threads = []
      threads << Thread.new do
        stdout.each_line do |line|
          formatted_line = line.chomp.gsub('\\n', "\n")
          if !silent
            puts formatted_line
          end
          stdout_str << line
        end
      end

      threads << Thread.new do
        stderr.each_line do |line|
          formatted_line = line.chomp.gsub('\\n', "\n")
          warn formatted_line
          stderr_str << line
        end
      end

      threads.each(&:join)

      exit_status = wait_thr.value
      return stdout_str, stderr_str, exit_status
    end
  end
end
