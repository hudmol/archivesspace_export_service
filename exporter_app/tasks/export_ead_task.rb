require 'fileutils'
require 'json'
require_relative 'lib/sqlite_work_queue'
require_relative 'lib/archivesspace_client'

class ExportEADTask

  EXPORTED_DIR = 'exported'

  def initialize(task_params)
    @workspace_directory = File.absolute_path(task_params.fetch(:workspace_directory))
    # @pipeline = task_params.fetch(:pipeline)

    @db_dir = File.join(@workspace_directory, "db")
    @work_queue = SQLiteWorkQueue.new(File.join(@db_dir, "ead_export.sqlite"))

    config = ExporterApp.config
    @as_client = ArchivesSpaceClient.new(config[:aspace_backend_url], config[:aspace_username], config[:aspace_password])

    @export_options = task_params.fetch(:export_options)
  end

  def call(process)
    now = Time.now
    last_read_time = @work_queue.get_int_status("last_read_time") { 0 }

    updates = @as_client.updates_since(last_read_time)

    load_into_work_queue(updates)
    create_manifest

    while item = @work_queue.next
      if item[:action] == 'add'
        download_ead(item[:resource_id], item[:repo_id])
      elsif item[:action] == 'remove'
        remove_ead(item[:resource_id])
      else
        puts "Unknown action for item: #{item.inspect}"
      end

      update_manifest(item)

      @work_queue.done(item)
    end

    @work_queue.put_int_status("last_read_time", now.to_i)
  end

  private

  def load_into_work_queue(updates)
    updates['adds'].each do |add|
      @work_queue.push('add', add['id'], {
                         'title' => add['title'],
                         'identifier' => add['identifier'].to_json,
                         'repo_id' => add['repo_id'],
                         'uri' => add['uri'],
                       })
    end

    # James says that I'll never need the format of the remove list to be the
    # same as the format of the add list, so the add list contains objects,
    # while the remove list contains integers.  Please remove this comment and
    # update the code below when I'm eventually proven right.
    #
    # -- Mark (Wednesday 20 April  15:38:14 AEST 2016)
    #
    # Still don't seem to need it ...
    #
    # -- James (Fri Apr 29 14:31:38 AEST 2016)
    #
    updates['removes'].each do |remove_id|
      @work_queue.push('remove', remove_id)
    end

    @work_queue.optimize
  end

  def ead_export_directory
    FileUtils.mkdir_p(File.join(@workspace_directory, EXPORTED_DIR))
  end

  def ead_export_file(id)
    File.join(ead_export_directory, "#{id}.xml")
  end

  def download_ead(id, repo_id)
    File.open(ead_export_file(id), 'w') do |io|
      io.write(@as_client.export(id, repo_id, @export_options))
    end
  end

  def remove_ead(id)
    File.delete(ead_export_file(id))
  rescue Errno::ENOENT
    # so it's not there, that's cool
  end

  def manifest_json_file
    File.join(ead_export_directory, "manifest.json")
  end

  def create_manifest
    File.open(manifest_json_file, 'w') do |io|
      io.write([].to_json)
    end
  end

  def update_manifest(item)
    ead_file = ead_export_file(item[:id])

    File.open(manifest_json_file, 'w') do |io|
      # either add or remove item from json
    end
  end
end
