require 'fileutils'
require 'json'
require_relative 'task_interface'
require_relative 'lib/xml_cleaner'
require_relative 'lib/xsd_validator'
require_relative 'lib/xslt_processor'
require_relative 'lib/sqlite_work_queue'
require_relative 'lib/archivesspace_client'

class ExportEADTask < TaskInterface

  EXPORTED_DIR = 'exported'

  def initialize(task_params, job_identifier, workspace_base)
    @workspace_directory = workspace_base
    @export_directory = File.join(workspace_base, EXPORTED_DIR)
    @subdirectory = job_identifier

    @db_dir = File.join(@workspace_directory, "db")
    @work_queue = SQLiteWorkQueue.new(File.join(@db_dir, "ead_export.sqlite"))

    config = ExporterApp.config
    @as_client = ArchivesSpaceClient.new(config[:aspace_backend_url], config[:aspace_username], config[:aspace_password])

    @validation_schema = task_params.fetch(:validation_schema, [])
    @xslt_transforms = task_params.fetch(:xslt_transforms, [])

    @search_options = task_params.fetch(:search_options)
    @export_options = task_params.fetch(:export_options)

    @log = ExporterApp.log_for(job_identifier)
    @log.info("ExportEADTask initialized")
  end

  def call(process)
    now = Time.now
    last_read_time = @work_queue.get_int_status("last_read_time") { 0 }
    @log.debug("Last read time: #{last_read_time}")

    updates = @as_client.updates_since(last_read_time, sanitized_search_options)
    @log.debug("Updates from ArchivesSpace: #{updates}")

    load_into_work_queue(updates)

    while (still_running = process.running?) && (item = @work_queue.next)
      if item[:action] == 'add'
        begin
          download_ead(item)
          create_manifest_json(item)
        rescue XSDValidator::ValidationFailedException => e
          @log.error("EAD validation failed for record #{item[:uri]} with the following error:")
          @log.error(e)

          # THINKME: At the moment we just log this warning and skip over the
          # record, never to be exported again until next changed in
          # ArchivesSpace.
        end
      elsif item[:action] == 'remove'
        @log.debug("Removing EAD and manifest for #{item[:uri]}")
        remove_ead_and_manifest(item[:resource_id])
      else
        @log.error("Unknown action for item: #{item[:uri]}")
      end

      @work_queue.done(item)
    end

    if !still_running
      @log.info("Task finished when end of window was reached")
    elsif !item
      @log.info("Work queue completed!")
    end

    @work_queue.put_int_status("last_read_time", now.to_i)
  end

  def exported_variables
    {
      :workspace_directory => @workspace_directory,
      :export_directory => @export_directory,
      :subdirectory => @subdirectory,
    }
  end

  private

  def load_into_work_queue(updates)
    @log.debug("Loading updates into work queue")
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

  def path_for_export_file(basename, extension = 'xml')
    output_directory = File.join(@export_directory, @subdirectory)
    FileUtils.mkdir_p(output_directory)

    File.join(output_directory, "#{basename}.#{extension}")
  end

  def download_ead(item)
    @log.debug("Downloading EAD for #{item[:uri]}")
    id = item.fetch(:resource_id)
    repo_id = item.fetch(:repo_id)

    outfile = path_for_export_file(id, 'xml')
    tempfile = "#{outfile}.tmp"

    File.open(tempfile, 'w') do |io|
      ead = @as_client.export(id, repo_id, @export_options)

      io.write(ead)
    end

    @log.debug("Cleaning XML for #{item[:uri]}")
    # Make sure we don't have any stray namespaces that will trip up the
    # subsequent validations/transformations.
    XMLCleaner.new.clean(tempfile)

    begin
      @log.debug("Running XSLT for #{item[:uri]}")
      run_xslt_transforms(item[:identifier], tempfile)
    rescue
      @log.debug("XSLT failed for #{item[:uri]}, tidying up")
      File.delete(tempfile)
      raise $!
    end

    begin
      @log.debug("Validating EAD for #{item[:uri]}")
      validate_ead!(item[:identifier], tempfile)
    rescue
      @log.debug("EAD validation failed for #{item[:uri]}, tidying up")
      File.delete(tempfile)
      raise $!
    end

    File.rename(tempfile, outfile)
    @log.debug("EAD download successful for #{item[:uri]}")
  end

  def create_manifest_json(item)
    @log.debug("Creating manifest json for #{item[:uri]}")
    outfile = path_for_export_file(item[:resource_id], 'json')

    File.open("#{outfile}.tmp", 'w') do |io|
      io.write({
        :resource_db_id => item[:resource_id],
        :ead_id => item[:ead_id],
        :identifier => JSON.parse(item[:identifier]).compact.join("."),
        :uri => item[:uri],
        :title => item[:title],
        :ead_file => File.basename(path_for_export_file(item[:resource_id], 'xml')),
      }.to_json)
    end

    File.rename("#{outfile}.tmp", outfile)
    @log.debug("Manifest json created for #{item[:uri]}")
  end

  def remove_ead_and_manifest(id)
    [path_for_export_file(id, 'xml'), path_for_export_file("#{id}", 'json')].each do |file|
      begin
        File.delete(file)
      rescue Errno::ENOENT
        # so it's not there, that's cool
      end
    end
  end

  def validate_ead!(identifier, file_to_validate)
    @validation_schema.each do |schema_file|
      XSDValidator.new(schema_file).validate(identifier, file_to_validate)
    end
  end

  def run_xslt_transforms(identifier, tempfile)
    @xslt_transforms.each do |xslt|
      # in-place transform
      XSLTProcessor.new(xslt).transform(identifier, tempfile, tempfile)
    end
  end

  def sanitized_search_options
    out = {}

    if @search_options[:repo_id]
      out[:repo_id] = @search_options[:repo_id]
    end

    if @search_options[:identifier]
      out[:start_id] = jsonize_id(@search_options[:identifier])
    else
      if @search_options[:start_id]
        out[:start_id] = jsonize_id(@search_options[:start_id])
      end
      if @search_options[:end_id]
        out[:end_id] = jsonize_id(@search_options[:end_id])
      end
    end

    out
  end

  def jsonize_id(id)
    out = Array.new(4)
    ida = id.split('.')
    ida.each_index do |ix|
      out[ix] = ida[ix]
    end
    out.take(4).to_json
  end
end
