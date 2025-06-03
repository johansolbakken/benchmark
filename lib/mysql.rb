# lib/mysql.rb

require 'open3'
require_relative './stream'
require_relative './color'

module MySQL
  VERSION = '0.0.1'

  # MySQL::Client
  #
  # This class provides an interface to execute MySQL commands via the MySQL client.
  # It encapsulates connection settings (user, port, host, and database name) and
  # provides instance methods to run queries directly or execute SQL files.
  #
  # Example usage:
  #
  #   client = MySQL::Client.new('my_user', 3306, 'localhost', 'my_database', '/usr/bin/mysql')
  #   client.run_query_without_db("DROP DATABASE IF EXISTS my_database;")
  #   client.run_query("USE my_database; SHOW TABLES;")
  #   client.run_file('path/to/file.sql')
  #
  class Client
    attr_accessor :db_user, :db_port, :db_host, :db_name, :mysql_client_path

    ##
    # Initializes a new MySQL client with the given connection parameters.
    #
    # @param [String] db_user The MySQL user.
    # @param [Integer, String] db_port The MySQL port.
    # @param [String] db_host The MySQL host.
    # @param [String] db_name The database name.
    # @param [String] mysql_client_path The path to the MySQL client executable (default: 'mysql').
    # @param [Boolean] silent Whether to suppress some of the output (default: false).
    def initialize(db_user, db_port, db_host, db_name, mysql_client_path = 'mysql', silent=false)
      @db_user = db_user
      @db_port = db_port
      @db_host = db_host
      @db_name = db_name
      @mysql_client_path = mysql_client_path
      @silent = silent
    end

    ##
    # Executes a SQL query that does not require a specific database context.
    #
    # @param [String] query The SQL query to be executed.
    # @return [Boolean] True if the query executed successfully, false otherwise.
    def run_query_without_db(query)
      command = "#{@mysql_client_path} -u#{@db_user} --local-infile=1 --port=#{@db_port} --host=#{@db_host}"
      _stdout, stderr, status = Stream.run_command_with_input(command, query, silent=@silent)
      warn stderr unless stderr.strip.empty?
      status.success?
    rescue StandardError => e
      warn "Error executing query without db: #{e.message}"
      false
    end

    ##
    # Executes a SQL query on the configured database.
    #
    # @param [String] query The SQL query to be executed.
    # @return [Boolean] True if the query executed successfully, false otherwise.
    def run_query(query)
      command = "#{@mysql_client_path} -u#{@db_user} --local-infile=1 --port=#{@db_port} --host=#{@db_host} #{@db_name}"
      _stdout, stderr, status = Stream.run_command_with_input(command, query, silent=@silent)
      warn stderr unless stderr.strip.empty?
      status.success?
    rescue StandardError => e
      warn "Error executing query on db: #{e.message}"
      false
    end

    def run_query_get_stdout(query)
      command = "#{@mysql_client_path} -u#{@db_user} --local-infile=1 --port=#{@db_port} --host=#{@db_host} #{@db_name}"
      stdout, stderr, status = Stream.run_command_with_input(command, query, silent=@silent)
      [stdout, stderr, status.success?]
    rescue StandardError => e
      warn "Error executing query on db: #{e.message}"
      ["", "", false]
    end

    def run_query_get_rows(query)
      command = "#{@mysql_client_path} -u#{@db_user} --local-infile=1 --port=#{@db_port} --host=#{@db_host} #{@db_name}"
      stdout, stderr, status = Stream.run_command_with_input(command, query, silent=@silent)
      rows = stdout.split("\n").map { |row| row.split("\t") }
      [rows, stderr, status.success?]
    rescue StandardError => e
      warn "Error executing query on db: #{e.message}"
      [[], "", false]
    end

    ##
    # Executes a SQL file on the configured database.
    #
    # @param [String] file The path to the SQL file.
    # @return [Boolean] True if the file executed successfully, false otherwise.
    def run_file(file)
      puts "#{Color.bold('Running file')}: #{file}"
      sql = File.read(file)
      command = "#{@mysql_client_path} -u#{@db_user} --local-infile=1 --port=#{@db_port} --host=#{@db_host} #{@db_name}"
      stdout, stderr, status = Stream.run_command_with_input(command, sql)
      puts stdout unless stdout.strip.empty?
      warn stderr unless stderr.strip.empty?
      status.success?
    rescue StandardError => e
      warn "Error executing SQL file: #{e.message}"
      false
    end

    ##
    # Switches the current database for subsequent queries.
    #
    # @param [String] new_db_name The new database name to use.
    def use_database(new_db_name)
      @db_name = new_db_name
    end
  end
end
