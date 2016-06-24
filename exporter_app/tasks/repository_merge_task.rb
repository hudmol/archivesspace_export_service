require 'fileutils'
require_relative 'task_interface'

class RepositoryMergeTask < TaskInterface

  # ASCII record separator
  RECORD_SEP = 30.chr

  def initialize(task_params, job_identifier, workspace_base)
    @workspace_directory = workspace_base
    @jobs_to_merge = task_params.fetch(:jobs_to_merge)
    @git_remote = task_params.fetch(:git_remote, '')

    @additional_file_paths = task_params.fetch(:include_additional_files_from, []).map {|path|
      ExporterApp.base_dir(path)
    }

    @log = ExporterApp.log_for(job_identifier)
  end

  def call(process)
    repositories = @jobs_to_merge.map {|id| ExporterApp.workspace_for_job(id)}
    @log.debug("Repositories to merge: #{repositories}")

    @log.debug("Running shell script")
    runner = ShellRunner.new("scripts/repository_merge.sh")
    runner.call(self, *repositories)
  end

  def exported_variables
    {
      :workspace_directory => @workspace_directory,
      :exported_directory => ExportEADTask::EXPORTED_DIR,
      :additional_file_paths => @additional_file_paths.join(RECORD_SEP),
      :git_remote => @git_remote,
      :ssh_wrapper => ExporterApp.base_dir("bin/ssh_wrapper.sh")
    }
  end

end
