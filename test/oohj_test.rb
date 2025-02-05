#!/usr/bin/env ruby
require 'yaml'
require 'open3'
require_relative '../lib/test_suite'
require_relative '../lib/color'

# Load your YAML configuration.
yaml_file = 'tests.yaml'
data = YAML.load_file(yaml_file)

total_tests = 0
passed_tests = 0
failed_tests = 0

# (Optionally) Run any global setup from the YAML.
if data['setup']
  TestSuite.run_initial_setup(data['setup'].map { |cmd| { cmd: cmd, desc: "Global setup" } })
end

# Iterate through the test groups in the YAML.
data['tests'].each do |group_name, group_data|
  if group_data['setup']
    TestSuite.run_initial_setup(group_data['setup'].map { |cmd| { cmd: cmd, desc: "Group setup" } })
  end

  if group_data['tests']
    group_data['tests'].each do |test|
      total_tests += 1
      if test['setup']
        TestSuite.run_initial_setup(test['setup'].map { |cmd| { cmd: cmd, desc: "Test setup" } })
      end

      puts Color.bold("[#{Color.blue('TEST')}]: #{test['name']}")

      # For diff_test, run a SQLJob.
      if group_name == "diff_test"
        unless test['sql'] && test['expected']
          abort("Error in test '#{test['name']}': both 'sql' and 'expected' are required for diff_test.")
        end

        job = TestSuite::SQLJob.new(test['sql'], test['expected'])
        if job.run
          puts Color.green("Output matches expected output.")
          passed_tests += 1
        else
          puts Color.red("Test failed!")
          failed_tests += 1
        end

      # For contain_test, run the command and check that output contains the expected substrings.
      elsif group_name == "contain_test"
        unless test['sql'] && test['contains']
          abort("Error in test '#{test['name']}': both 'sql' and 'contains' are required for contain_test.")
        end

        # In this example, we assume the SQL file is executed via benchmark.rb.
        command = "ruby ./bin/benchmark.rb --run #{test['sql']}"
        output, _stderr, _status = Open3.capture3(command)

        test_success = true
        test['contains'].each do |substring|
          if output.include?(substring)
            puts Color.green("  Found expected substring: #{substring}")
          else
            puts Color.red("  Missing expected substring: #{substring}")
            test_success = false
          end
        end

        if test_success
          passed_tests += 1
        else
          failed_tests += 1
        end
      end
      puts
    end
  end
end

# Print the summary.
puts Color.bold("Test Summary:")
puts Color.bold("Total tests run: #{total_tests}")
puts Color.green("Passed: #{passed_tests}")
puts Color.red("Failed: #{failed_tests}")
