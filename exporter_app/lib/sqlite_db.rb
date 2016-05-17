require 'fileutils'

class SQLiteDB

  def initialize(db_file)
    java.lang.Class.for_name("org.sqlite.JDBC")
    @db_file = db_file
  end

  def with_connection
    connection = nil
    begin
      FileUtils.mkdir_p(File.dirname(@db_file))
      connection = java.sql.DriverManager.get_connection("jdbc:sqlite:#{@db_file}")
      yield Connection.new(connection)
    ensure
      if connection
        connection.close
      else
        raise "DB Connection failed: #{@db_file}"
      end
    end
  end

  class Connection
    def initialize(jdbc_connection)
      @jdbc_connection = jdbc_connection
    end

    def prepare(sql, arguments = [])
      statement = @jdbc_connection.prepare_statement(sql)

      arguments.each_with_index do |argument, i|
        if argument.is_a?(String)
          statement.set_string(i + 1, argument)
        elsif argument.is_a?(Integer)
          statement.set_int(i + 1, argument)
        else
          raise "Unrecognized argument type: #{argument.class} in arguments #{arguments.inspect}"
        end
      end

      yield statement
    rescue java.sql.SQLException
      $stderr.puts("SQL failed: #{sql}: #{$!}")
    ensure
      statement.close if statement
    end

    def create_statement
      @jdbc_connection.create_statement
    end
  end

end
