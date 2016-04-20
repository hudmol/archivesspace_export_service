require 'fileutils'
require_relative 'lib/sqlite_work_queue'

class ExportEADTask

  def initialize(task_params)
    @workspace_directory = File.absolute_path(task_params.fetch(:workspace_directory))
    # @pipeline = task_params.fetch(:pipeline)

    @db_dir = File.join(@workspace_directory, "db")
    @work_queue = SQLiteWorkQueue.new(File.join(@db_dir, "ead_export.sqlite"))
  end

  def call(process)
    now = Time.now
    last_read_time = @work_queue.get_int_status("last_read_time") { 0 }

    # do the needful

    @work_queue.put_int_status("last_read_time", now.to_i)
  end

end
