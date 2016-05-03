require 'fileutils'
require 'json'
require_relative 'task_interface'
require_relative 'lib/xsd_validator'
require_relative 'lib/sqlite_work_queue'
require_relative 'lib/archivesspace_client'

class ExportEADTask < TaskInterface

  EXPORTED_DIR = 'exported'

  def initialize(task_params)
    @workspace_directory = File.absolute_path(task_params.fetch(:workspace_directory))
    # @pipeline = task_params.fetch(:pipeline)

    @db_dir = File.join(@workspace_directory, "db")
    @work_queue = SQLiteWorkQueue.new(File.join(@db_dir, "ead_export.sqlite"))

    config = ExporterApp.config
    @as_client = ArchivesSpaceClient.new(config[:aspace_backend_url], config[:aspace_username], config[:aspace_password])

    @archivesspace_ead_schema = task_params.fetch(:archivesspace_ead_schema, nil)

    @export_options = task_params.fetch(:export_options)
  end

  def call(process)
    now = Time.now
    last_read_time = @work_queue.get_int_status("last_read_time") { 0 }

    updates = @as_client.updates_since(last_read_time)

    load_into_work_queue(updates)

    while item = @work_queue.next
      if item[:action] == 'add'
        begin
          download_ead(item)
          create_manifest_json(item)
        rescue XSDValidator::ValidationFailedException => e
          puts "EAD validation failed for record #{item[:identifier]} with the following error:\n"
          puts e

          # THINKME: At the moment we just log this warning and skip over the
          # record, never to be exported again until next changed in
          # ArchivesSpace.
        end
      elsif item[:action] == 'remove'
        remove_ead_and_manifest(item[:resource_id])
      else
        puts "Unknown action for item: #{item.inspect}"
      end

      @work_queue.done(item)
    end

    @work_queue.put_int_status("last_read_time", now.to_i)
  end

  def exported_variables
    {
      :workspace_directory => @workspace_directory,
      :export_directory => File.join(@workspace_directory, EXPORTED_DIR)
    }
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
    # I hate it when James is right :(
    #
    # -- Mark (Tuesday 3 May  10:26:28 AEST 2016)
    #
    updates['removes'].each do |remove_id|
      @work_queue.push('remove', remove_id)
    end

    @work_queue.optimize
  end

  def ead_export_directory
    FileUtils.mkdir_p(File.join(@workspace_directory, EXPORTED_DIR))
  end

  def path_for_export_file(basename, extension = 'xml')
    File.join(ead_export_directory, "#{basename}.#{extension}")
  end

  def download_ead(item)
    id = item.fetch(:resource_id)
    repo_id = item.fetch(:repo_id)

    outfile = path_for_export_file(id, 'xml')
    tempfile = "#{outfile}.tmp"

    File.open(tempfile, 'w') do |io|
      io.write(@as_client.export(id, repo_id, @export_options))
    end

    begin
      validate_ead!(item[:identifier], tempfile)
    rescue
      File.delete(tempfile)
      raise $!
    end

    File.rename(tempfile, outfile)
  end

  def create_manifest_json(item)
    outfile = path_for_export_file("#{item[:resource_id]}", 'json')

    File.open("#{outfile}.tmp", 'w') do |io|
      io.write({
        :resource_db_id => item[:resource_id],
        :uri => item[:uri],
        :title => item[:title],
      }.to_json)
    end

    File.rename("#{outfile}.tmp", outfile)
  end

  def remove_ead_and_manifest(id)
    [path_for_export_file(id, 'xml'), path_for_export_file("#{id}", 'json')].each do |file|
      begin
        File.delete(file)
      rescue Errno::NOENT
        # so it's not there, that's cool
      end
    end
  end

  def validate_ead!(identifier, file)
    return unless @archivesspace_ead_schema

    XSDValidator.new(@archivesspace_ead_schema).validate(identifier, file)
  end

end
