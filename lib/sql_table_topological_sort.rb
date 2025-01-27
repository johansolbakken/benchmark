# lib/sql_table_topological_sort.rb

module Sql_Table_Topological_Sort
  VERSION = '0.0.1'

  class << self
    require 'pg_query'

    # Parse SQL schema and extract table dependencies
    def extract_dependencies(sql_schema)
      dependencies = Hash.new { |hash, key| hash[key] = [] }

      sql_schema.split(/;/).each do |statement|
        next if statement.strip.empty?

        # Parse each SQL statement
        parsed = PgQuery.parse(statement)

        parsed.tree.stmts.each do |stmt|
          create_stmt = stmt.stmt.create_stmt
          next unless create_stmt

          table_name = create_stmt.relation.relname
          constraints = create_stmt.table_elts
          dependencies[table_name] # Initialize the table in the hash

          next unless table_name && constraints

          constraints.each do |constraint|
            next unless constraint.constraint && constraint.constraint.fk_attrs

            fk_table = constraint.constraint.pktable&.relname
            dependencies[table_name] << fk_table if fk_table
          end
        end
      end

      dependencies
    end

    # Perform topological sort on the dependency graph
    def topological_sort(dependencies)
      sorted = []
      visited = {}

      visit = lambda do |node|
        return if visited[node] == :permanent
        raise "Cyclic dependency detected" if visited[node] == :temporary

        visited[node] = :temporary
        dependencies[node].each { |neighbor| visit.call(neighbor) } if dependencies[node]
        visited[node] = :permanent
        sorted << node
      end

      dependencies.keys.each { |node| visit.call(node) unless visited[node] }
      sorted
    end

    # Public API: Parse schema and return sorted table names
    def sort_tables(sql_schema)
      dependencies = extract_dependencies(sql_schema)
      topological_sort(dependencies)
    end
  end
end
