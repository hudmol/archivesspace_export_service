class SQLiteWorkQueue

  def initialize(db_file)
    @db = SQLiteDB.new(db_file)

    create_tables
  end

  def push(action, resource_id, extra_args = {})
    @db.with_connection do |conn|
      extra_args_columns = extra_args.empty? ? '' : (', ' + extra_args.keys.join(', '))
      extra_args_placeholders = extra_args.empty? ? '' : (', ' + (['?'] * extra_args.length).join(', '))
      conn.prepare("insert into work_queue (action, resource_id#{extra_args_columns}) values (?, ?#{extra_args_placeholders})",
                   [action, resource_id, *extra_args.values]) do |statement|
        statement.execute_update
      end
    end
  end

  def next
    @db.with_connection do |conn|
      conn.prepare("select id, resource_id, action, identifier, repo_id, title, uri, ead_id from work_queue order by id limit 1") do |statement|
        rs = statement.execute_query
        while rs.next
          return {
            :id => rs.get_int(1),
            :resource_id => rs.get_int(2),
            :action => rs.get_string(3),
            :identifier => rs.get_string(4),
            :repo_id => rs.get_int(5),
            :title => rs.get_string(6),
            :uri => rs.get_string(7),
            :ead_id => rs.get_string(8),
          }
        end
      end
    end
  end

  def done(item)
    @db.with_connection do |conn|
      conn.prepare("delete from work_queue where id = ?", [item[:id]]) do |statement|
        statement.execute_update
      end
    end
  end

  def list
    result = []

    @db.with_connection do |conn|
      conn.prepare("select resource_id, identifier from work_queue") do |statement|
        rs = statement.execute_query

        while rs.next
          result << [rs.get_int(1), rs.get_string(2)]
        end
      end
    end

    result
  end

  def get_int_status(key, &block)
    @db.with_connection do |conn|
      conn.prepare("select int_value from status where key = ?", [key]) do |statement|
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
    @db.with_connection do |conn|
      conn.prepare("insert or replace into status (key, int_value) values (?, ?)", [key, value]) do |statement|
        statement.execute_update
      end
    end
  end

  def optimize
    # We can save ourselves some work by trimming the work queue to remove redundancy.

    @db.with_connection do |conn|
      # If an 'add' entry for a resource is followed by a 'remove' entry, we can
      # discard the 'add' (since we would just delete the record moments later
      # anyway).
      conn.prepare("delete from work_queue where id in " +
                   " (select wq1.id from work_queue wq1 " +
                   "   inner join work_queue wq2 on wq1.resource_id = wq2.resource_id " +
                   "   where wq1.action = 'add' AND wq2.action = 'remove' " +
                   "     AND wq1.id < wq2.id)") do |statement|
        statement.execute_update
      end

      # If there are two 'add' entries for the same resource ID, just keep the
      # last one.
      #
      # Note: previously we just kept the first one, but there's additional
      # metadata that we get from the plugin (such as the resource 4-part
      # identifier) that we want to be as up-to-date as possible.  If delete all
      # but the first row, we end up writing out EAD with the wrong
      # identifier/metadata.
      #
      # Taking the last identifier does mean the resource won't get exported as
      # quickly as it otherwise would, but in practice that might not matter.
      conn.prepare("delete from work_queue " +
                   "where action = 'add' and id not in " +
                   " (select max(id) from work_queue " +
                   "    where action = 'add' group by resource_id)") do |statement|
        statement.execute_update
      end
    end
  end

  def create_tables
    @db.with_connection do |conn|
      statement = conn.create_statement
      statement.execute_update("create table if not exists work_queue" +
                               " (id integer primary key autoincrement," +
                               " action text, resource_id integer, identifier text," +
                               " repo_id integer, title text, uri text, ead_id text)")

      statement.execute_update("create table if not exists status" +
                               " (key primary key, int_value integer)")

    end
  end
end
