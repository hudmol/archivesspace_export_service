require 'fileutils'
require 'json'
require_relative 'task_interface'
require_relative 'lib/xml_cleaner'
require_relative 'lib/xsd_validator'
require_relative 'lib/schematron_validator'
require_relative 'lib/xslt_processor'
require_relative 'lib/sqlite_work_queue'
require_relative 'lib/archivesspace_client'
require_relative 'lib/handle_client'
require_relative 'lib/validation_failed_exception'

class ExportEADTask < TaskInterface

  # Adjust our timestamps to avoid time differences between servers, delays
  # between transactions committing and becoming apparent, etc.
  READ_MARGIN_SECONDS = 120

  EXPORTED_DIR = 'exported'

  class SkipRecordException < StandardError
  end

  def initialize(task_params, job_identifier, workspace_base)
    @workspace_directory = workspace_base
    @export_directory = File.join(workspace_base, EXPORTED_DIR)
    @subdirectory = job_identifier

    @db_dir = File.join(@workspace_directory, "db")
    @work_queue = SQLiteWorkQueue.new(File.join(@db_dir, "ead_export.sqlite"))

    config = ExporterApp.config
    @as_client = ArchivesSpaceClient.new(config[:aspace_backend_url], config[:aspace_username], config[:aspace_password])

    if (@generate_handles = task_params.fetch(:generate_handles, false))
      @handle_client = HandleClient.new(config[:handle_wsdl_url],
                                        config[:handle_user],
                                        config[:handle_credential],
                                        config[:handle_prefix],
                                        config[:handle_group],
                                        config[:handle_base])
    end

    @commit_every_n_records = task_params.fetch(:commit_every_n_records, nil)
    @records_added = 0

    @validation_schema = task_params.fetch(:validation_schema, [])
    @schematron_checks = task_params.fetch(:schematron_checks, [])

    @xslt_transforms = task_params.fetch(:xslt_transforms, [])

    @search_options = task_params.fetch(:search_options)
    @export_options = task_params.fetch(:export_options)

    @last_start_time = nil

    @log = ExporterApp.log_for(job_identifier)
  end

  def call(process)
    @last_start_time = Time.now
    last_read_time = @work_queue.get_int_status("last_read_time") { 0 }
    @log.debug("Last read time: #{last_read_time}")

    if last_read_time > 0
      last_read_time -= READ_MARGIN_SECONDS
    end

    updates = @as_client.updates_since(last_read_time, sanitized_search_options)
    @log.debug("Updates from ArchivesSpace: #{updates}")

    load_into_work_queue(updates)

    @records_added = 0

    while (still_running = process.running?) && !max_records_hit? && (item = @work_queue.next)
      if item[:action] == 'add'
        begin
          ensure_handle(item) if @generate_handles
          download_ead(item)
          create_manifest_json(item)
        rescue SkipRecordException
          # Skip this record and continue the jobs
        end
        @records_added += 1
      elsif item[:action] == 'remove'
        @log.info("Removing EAD and manifest for #{item}")
        remove_associated_files(item[:resource_id])
      else
        @log.error("Unknown action for item: #{item}")
      end

      @log.debug("Record completed and removed from queue: #{item[:uri]}") if item[:uri]
      @work_queue.done(item)
    end

    if !still_running
      @log.info("Task finished when end of window was reached")
    elsif !item
      @log.info("Work queue completed!")
    end

  end

  def completed!
    # Record a successful run
    @work_queue.put_int_status("last_read_time", @last_start_time.to_i)
  end

  def exported_variables
    {
      :workspace_directory => @workspace_directory,
      :export_directory => @export_directory,
      :subdirectory => @subdirectory,
    }
  end

  private

  def max_records_hit?
    @commit_every_n_records && @records_added >= @commit_every_n_records
  end

  def load_into_work_queue(updates)
    @log.info("Loading updates into work queue")
    @work_queue.push('add',
                     updates['adds'].map {|record|
                       # We want to store identifiers as JSON strings, so fix
                       # them up here.
                       record.merge('identifier' => record['identifier'].to_json)
                     })

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
    # Apropos nothing in particular... if the remove list format had the same
    # structure as the add list format, I wouldn't need to turn them into hashes
    # myself below...
    #
    # -- Mark (Monday 27 June  15:49:39 AEST 2016)
    @work_queue.push('remove',
                     updates['removes'].map {|removed_id| {'id' => removed_id}})

    @work_queue.optimize
  end

  def path_for_export_file(basename, extension = 'xml')
    output_directory = File.join(@export_directory, @subdirectory)
    FileUtils.mkdir_p(output_directory)

    File.join(output_directory, "#{basename}.#{extension}")
  end

  def ensure_handle(item)
    @log.info("Ensuring there is a handle for #{item[:uri]}")
    @log.debug("ead_id: '#{item[:ead_id]}', ead_location: '#{item[:ead_location]}'")

    if !item[:ead_location] && item[:ead_id]
      begin
        handle = @handle_client.create_handle(item[:ead_id], item[:uri])
        @log.info("Created handle: #{handle} for #{item[:uri]}")
        response = @as_client.update_record(item[:uri], 'ead_location' => handle)
        @log.debug("Updated resource: #{response}")
      rescue
        @log.error("Failed to create handle for #{item[:uri]}: #{$!}")
      end
    else
      @log.debug("No need to create handle")
    end
  end

  def download_ead(item)
    @log.info("Downloading EAD for #{item[:uri]}")
    id = item.fetch(:resource_id)
    repo_id = item.fetch(:repo_id)

    outfile = path_for_export_file(id, 'xml')
    tempfile = "#{outfile}.tmp"

    File.open(tempfile, 'w') do |io|
      retries_remaining = 2

      begin
        ead = @as_client.export(id, repo_id, @export_options)
        io.write(ead)
      rescue Timeout::Error
        retries_remaining -= 1
        if retries_remaining > 0
          @log.info("Fetch for ID #{id} timed out.  Trying again!")
          retry
        else
          @log.info("Record #{id} is still timing out after several retries.  Giving up!")
          raise $!
        end
      end
    end

    @log.info("Cleaning XML for #{item[:uri]}")
    begin
      # Make sure we don't have any stray namespaces that will trip up the
      # subsequent validations/transformations.
      XMLCleaner.new.clean(tempfile)
    rescue
      @log.error("XML cleaning failed: #{$!}.  Skipping this record")
      raise SkipRecordException.new
    end

    begin
      @log.info("Running XSLT for #{item[:uri]}")
      run_xslt_transforms(item[:identifier], tempfile)
    rescue
      @log.info("XSLT failed for #{item[:uri]}, tidying up")
      File.delete(tempfile)
      raise $!
    end

    begin
      @log.info("Validating EAD for #{item[:uri]}")
      validate_ead!(item[:identifier], tempfile)
    rescue ValidationFailedException => e
      @log.error("EAD validation failed for #{item[:uri]}.  Skipping this record")
      @log.error("Validation error was: #{e}")

      File.delete(tempfile)
      raise SkipRecordException.new
    end

    File.rename(tempfile, outfile)
    @log.info("EAD download successful for #{item[:uri]}")
  end

  def create_manifest_json(item)
    @log.info("Creating manifest json for #{item[:uri]}")
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
    @log.info("Manifest json created for #{item[:uri]}")
  end

  def remove_associated_files(id)
    Dir.glob(path_for_export_file(id, '*')).each do |file|
      begin
        @log.info("Removing deleted file: #{file}")
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

    @schematron_checks.each do |schematron_file|
      SchematronValidator.new(schematron_file).validate(identifier, file_to_validate)
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
