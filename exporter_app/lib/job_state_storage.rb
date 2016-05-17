require_relative 'job_status'

class JobStateStorage

  class JobState < Struct.new(:last_start_time, :last_finish_time, :status)

    def self.from_row(rs)
      new(Time.at(rs.get_int("last_start_time")),
          Time.at(rs.get_int("last_finish_time")),
          rs.get_string("status"))
    end

    def running?
      status == JobStatus::RUNNING
    end

  end

  def initialize
    java.lang.Class.for_name("org.sqlite.JDBC")

    @db = SQLiteDB.new(ExporterApp.base_dir("workspace/job_state.db"))
    create_tables
    reset_running_jobs
  end

  def job_started(job)
    @db.with_connection do |conn|
      conn.prepare("insert or replace into job_state (job_id, last_start_time, status) values (?, ?, ?)",
                   [job.id, Time.now.to_i, JobStatus::RUNNING]) do |statement|
        statement.execute_update
      end
    end
  end

  def job_completed(job, status)
    @db.with_connection do |conn|
      conn.prepare("update job_state set last_finish_time = ?, status = ? where job_id = ?",
                   [Time.now.to_i, status, job.id]) do |statement|
        statement.execute_update
      end
    end
  end

  def last_run_of(job)
    @db.with_connection do |conn|
      conn.prepare("select * from job_state where job_id = ?", [job.id]) do |statement|
        rs = statement.execute_query
        begin
          if rs.next
            JobState.from_row(rs)
          else
            null_job_info
          end
        ensure
          rs.close
        end
      end
    end
  end

  def dump
    result = []
    @db.with_connection do |conn|
      conn.prepare("select * from job_state") do |statement|
        rs = statement.execute_query
        begin
          while rs.next
            result << JobState.from_row(rs)
          end
        ensure
          rs.close
        end
      end
    end

    puts ("=== Job states ===\n" +
          result.map(&:to_s).join("\n") +
          "\n=== End job states ===")
  end

  private

  def null_job_info
    JobState.new(Time.at(0), Time.at(0), 'never_started')
  end

  def create_tables
    @db.with_connection do |conn|
      statement = conn.create_statement
      statement.execute_update("create table if not exists job_state" +
                               " (job_id text primary key," +
                               "  last_start_time int8," +
                               "  last_finish_time int8," +
                               "  status text)")
    end
  end

  def reset_running_jobs
    @db.with_connection do |conn|
      conn.prepare("delete from job_state where status = ?",
                   [JobStatus::RUNNING]) do |statement|
        statement.execute_update
      end
    end
  end

end
