require 'fileutils'
require_relative 'lib/sqlite_work_queue'
require_relative 'lib/resource_update_feed'

class ExportEADTask

  def initialize(task_params)
    @workspace_directory = File.absolute_path(task_params.fetch(:workspace_directory))
    # @pipeline = task_params.fetch(:pipeline)

    @db_dir = File.join(@workspace_directory, "db")
    @work_queue = SQLiteWorkQueue.new(File.join(@db_dir, "ead_export.sqlite"))
  end

  def call(process)
    config = ExporterApp.config

    now = Time.now
    last_read_time = @work_queue.get_int_status("last_read_time") { 0 }

    feed = ResourceUpdateFeed.new(config[:aspace_backend_url], config[:aspace_username], config[:aspace_password])

    updates = feed.updates_since(last_read_time)

    p updates

    @work_queue.put_int_status("last_read_time", now.to_i)
  end

end
