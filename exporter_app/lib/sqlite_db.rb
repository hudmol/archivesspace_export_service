require 'fileutils'

class SQLiteDB

  def initialize(db_file)
    java.lang.Class.for_name("org.sqlite.JDBC")
    @db_file = db_file
    @log = ExporterApp.log_for(self.class.to_s)
  end

  def with_connection
    connection = nil
    begin
      FileUtils.mkdir_p(File.dirname(@db_file))
      connection = java.sql.DriverManager.get_connection("jdbc:sqlite:#{@db_file}")

      set_busy_timeout(connection, 60000)

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

    MAX_BUSY_RETRIES = 10
    MAX_RETRY_WAIT_MS = 5000

    def initialize(jdbc_connection)
      jdbc_connection.set_auto_commit(true)
      @jdbc_connection = jdbc_connection
      @log = ExporterApp.log_for(self.class.to_s)
    end

    def set_auto_commit(val)
      @jdbc_connection.set_auto_commit(val)
    end

    def commit
      @jdbc_connection.commit
    end

    def prepare(sql, arguments = [])
      retries_remaining = MAX_BUSY_RETRIES
      statement = @jdbc_connection.prepare_statement(sql)

      arguments.each_with_index do |argument, i|
        if argument.is_a?(String)
          statement.set_string(i + 1, argument)
        elsif argument.is_a?(Integer)
          statement.set_int(i + 1, argument)
        elsif argument.nil?
          # Skip it!
        else
          raise "Unrecognized argument type: #{argument.class} in arguments #{arguments.inspect}"
        end
      end

      yield statement

    rescue java.sql.SQLException => e
      if retries_remaining > 0 && e.message.to_s =~ /SQLITE_BUSY/
        statement.close if statement
        statement = nil

        sleep(rand(MAX_RETRY_WAIT_MS) / 1000.0)
        retries_remaining -= 1

        @log.info("Database was locked when we tried to write.  We'll retry shortly! (remaining retries: #{retries_remaining})...")

        retry
      end

      @log.error("SQL failed: #{sql}: #{e}")

    ensure
      statement.close if statement
    end

    def create_statement
      @jdbc_connection.create_statement
    end
  end

  private

  def set_busy_timeout(connection, timeout)
    timeout_statement = nil
    begin
      timeout_statement = connection.prepare_statement("pragma busy_timeout=#{timeout}")
      timeout_statement.execute
    ensure
      timeout_statement.close if timeout_statement
    end
  end

end
