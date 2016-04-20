class SQLiteWorkQueue

  def initialize(db_file)
    FileUtils.mkdir_p(File.dirname(db_file))

    @db_file = db_file

    java.lang.Class.for_name("org.sqlite.JDBC")
    create_tables
  end

  def push(resource_id, extra_args)
    with_connection do |conn|
      extra_args_columns = extra_args.keys.join(', ')
      extra_args_placeholders = (['?'] * extra_args.length).join(', ')
      prepare(conn,
              "insert into work_queue (resource_id, #{extra_args_columns}) values (?, #{extra_args_placeholders})",
              [resource_id, *extra_args.values]) do |statement|
        statement.execute_update
      end
    end
  end

  def list
    result = []

    with_connection do |conn|
      prepare(conn, "select resource_id, identifier from work_queue") do |statement|
        rs = statement.execute_query

        while rs.next
          result << [rs.get_int(1), rs.get_string(2)]
        end
      end
    end

    result
  end

  def get_int_status(key, &block)
    with_connection do |conn|
      prepare(conn, "select int_value from status where key = ?", [key]) do |statement|
        rs = statement.execute_query

        while rs.next
          return rs.get_int(1)
        end
      end
    end

    if block_given?
      block.call
    else
      raise "No status found for key: #{key}"
    end
  end

  def put_int_status(key, value)
    with_connection do |conn|
      prepare(conn, "insert or replace into status (key, int_value) values (?, ?)", [key, value]) do |statement|
        statement.execute_update
      end
    end
  end

  private

  def with_connection
    connection = nil
    begin
      connection = java.sql.DriverManager.get_connection("jdbc:sqlite:#{@db_file}")
    ensure
      connection.close
    end

    connection
  end

  def prepare(connection, sql, arguments = [])
    statement = connection.prepare_statement(sql)

    arguments.each_with_index do |argument, i|
      if argument.is_a?(String)
        statement.set_string(i + 1, argument)
      elsif argument.is_a?(Integer)
        statement.set_int(i + 1, argument)
      else
        raise "Unrecognized argument type: #{argument.class}"
      end
    end

    yield statement
  ensure
    statement.close
  end

  def create_tables
    with_connection do |conn|
      statement = conn.create_statement
      statement.execute_update("create table if not exists work_queue" +
                               " (id integer primary key autoincrement, resource_id integer, identifier text)")

      statement.execute_update("create table if not exists status" +
                               " (key primary key, int_value integer)")

    end
  end
end
