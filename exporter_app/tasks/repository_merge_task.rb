require 'fileutils'
require 'tmpdir'
require 'erb'
require_relative 'task_interface'

class RepositoryMergeTask < TaskInterface

  def initialize(task_params, job_identifier, workspace_base)
    @job_identifier = job_identifier
    @workspace_directory = workspace_base
    @jobs_to_merge = task_params.fetch(:jobs_to_merge)
    @job_descriptions = task_params.fetch(:job_descriptions, {})
    @git_remote = task_params.fetch(:git_remote, '')

    # Scratch space for processing our additional files
    @additional_file_tmpdir = Dir.mktmpdir

    prepare_additional_files(task_params.fetch(:include_additional_files_from, []))

    @log = ExporterApp.log_for(job_identifier)
  end

  def call(process)
    repositories = @jobs_to_merge.map {|id| ExporterApp.workspace_for_job(id)}
    @log.debug("Repositories to merge: #{repositories}")

    @log.debug("Running shell script")
    runner = ShellRunner.new("scripts/repository_merge.sh")
    runner.call(self, *repositories)
  ensure
    FileUtils.rm_rf(@additional_file_tmpdir) if @additional_file_tmpdir
  end

  def exported_variables
    {
      :job_identifier => @job_identifier,
      :workspace_directory => @workspace_directory,
      :exported_directory => ExportEADTask::EXPORTED_DIR,
      :additional_file_path => @additional_file_tmpdir,
      :git_remote => @git_remote,
      :ssh_wrapper => ExporterApp.base_dir("bin/ssh_wrapper.sh")
    }
  end

  private

  def prepare_additional_files(directories)
    directories.each do |path|
      path = ExporterApp.base_dir(path)

      Dir.glob(File.join(path, "*")).each do |file_to_include|
        if (File.extname(file_to_include) == '.erb')
          process_erb(file_to_include,
                      File.join(@additional_file_tmpdir, File.basename(file_to_include, '.erb')),
                      :jobs => @jobs_to_merge,
                      :job_descriptions => @job_descriptions)
        else
          FileUtils.cp_r(file_to_include, @additional_file_tmpdir)
        end
      end
    end
  end

  def process_erb(template, outfile, opts = {})
    renderer = ERB.new(File.read(template))
    data = TemplateData.new(opts)

    File.open(outfile, 'w') {|file|
      file.write(renderer.result(data.get_binding))
    }
  end

  class TemplateData
    def initialize(opts)
      opts.each do |k, v|
        instance_variable_set("@#{k}".intern, v)
      end
    end

    def get_binding
      binding
    end
  end


end
