require 'erb'
require_relative 'hook_interface'

class ErbRenderer < HookInterface

  def initialize(template_file, output_filename)
    @template_file = template_file
    @output_filename = output_filename
  end

  def call(task)
    renderer = ERB.new(File.read(@template_file))

    export_directory = task.exported_variables.fetch(:export_directory)
    subdirectory = task.exported_variables.fetch(:subdirectory)

    full_export_path = File.join(export_directory, subdirectory)

    # Nothing has been exported yet
    return if !Dir.exist?(full_export_path)

    data = TemplateData.new(combined_json(full_export_path))

    File.open(output_file(full_export_path), 'w') {|file|
      file.write(renderer.result(data.get_binding))
    }
  end

  private

  class TemplateData
    def initialize(data)
      @data = data
    end

    def get_binding
      binding()
    end
  end

  def combined_json(path)
    json = []

    json_files = File.join(path, "*.json")

    Dir.glob(json_files) do |filename|
      json.push(JSON.parse(File.read(filename)))
    end

    json.sort{|a, b| a[:resource_db_id] <=> b[:resource_db_id]}
  end

  def output_file(export_directory)
    File.join(export_directory, @output_filename)
  end
end
