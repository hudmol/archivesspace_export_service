require 'fileutils'
require 'json'
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

    load_into_work_queue(updates)

    # Do some work...

    @work_queue.put_int_status("last_read_time", now.to_i)
  end

  private

  def load_into_work_queue(updates)
    updates['adds'].each do |add|
      @work_queue.push('add', add['id'], {
                         'identifier' => add['identifier'].to_json
                       })
    end

    # James says that I'll never need the format of the remove list to be the
    # same as the format of the add list, so the add list contains objects,
    # while the remove list contains integers.  Please remove this comment and
    # update the code below when I'm eventually proven right.
    #
    # -- Mark (Wednesday 20 April  15:38:14 AEST 2016)
    #
    updates['removes'].each do |remove_id|
      @work_queue.push('remove', remove_id)
    end

    @work_queue.optimize
  end

end
