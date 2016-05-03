require_relative 'hook_interface'

class ShellRunner < HookInterface

  def initialize(script)
    @script = script
  end

  def call(task, *args)
    environment = Hash[task.exported_variables.map {|k, v| [k.to_s.upcase, v.to_s]}]

    ret = system(environment, expand_path(@script), *args)

    if ret
      # All OK
      return true
    elsif ret === false
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
