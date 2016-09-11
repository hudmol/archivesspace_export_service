require 'open3'
require_relative 'hook_interface'

class ShellRunner < HookInterface

  def initialize(script)
    @script = script
  end

  def call(task, *args)
    log = ExporterApp.log_for("ShellRunner")

    environment = Hash[task.exported_variables.map {|k, v| [k.to_s.upcase, v.to_s]}]

    log.debug("Running script: #{@script}")
    exit_status = -1
    Open3.popen3(environment, expand_path(@script), *args) do |stdin, stdout, stderr, wait_thr|
      stdin.close_write

      until stdout.eof && stderr.eof
        (readable,) = IO.select([stderr, stdout], [])
        readable.each do |fh|
          if fh == stderr
            fh.each do |line|
              log.info(line.chomp)
            end
          end

          if fh == stdout
            fh.each do |line|
              log.debug(line.chomp)
            end
          end
        end
      end

      exit_status = wait_thr.value.exitstatus
      log.debug("Exit status: #{exit_status}")
    end

    if exit_status == 0
      # All OK
      return true
    elsif exit_status > 0
      raise "#{@script} returned a non-zero status: #{$?}"
    else
      raise "#{@script} failed to execute: #{$?}"
    end
  end

  private

  def expand_path(script)
    # If `script` can be found in the project's directory, use that instead of relying on $PATH
    if File.exists?(ExporterApp.base_dir(script))
      ExporterApp.base_dir(script)
    else
      script
    end
  end

end
