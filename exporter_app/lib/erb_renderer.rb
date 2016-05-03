require 'erb'
require_relative 'hook_interface'

class ErbRenderer < HookInterface

  def initialize(template_file, output_filename)
    @template_file = template_file
    @output_filename = output_filename
  end

  def call(task)
    export_directory = task.exported_variables.fetch(:export_directory)

    renderer = ERB.new(File.read(@template_file))

    data = TemplateData.new(combined_json(export_directory))

    File.open(output_filename(export_directory), 'w') {|file|
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

  def combined_json(export_directory)
    json = []

    Dir.glob(File.join(export_directory, "*.json")) do |filename|
      json.push(JSON.parse(File.read(filename)))
    end

    json.sort{|a, b| a[:resource_db_id] <=> b[:resource_db_id]}
  end

  def output_filename(export_directory)
    File.join(export_directory, @output_filename)
  end
end