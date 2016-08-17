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
      record_json = JSON.parse(File.read(filename))

      record_json['other_versions'] ||= {}

      Dir.glob(File.join(path, "#{record_json.fetch('resource_db_id')}.*")).each do |file_version|
        next if file_version.downcase.end_with?(".tmp")

        name = File.basename(file_version)
        if File.basename(file_version) != record_json['ead_file'] && name != File.basename(filename)
          label = File.extname(file_version) == "" ? name : File.extname(file_version).upcase[1..-1]
          record_json['other_versions'][name] = label
        end
      end

      json.push(record_json)
    end

    json.sort{|a, b| a['resource_db_id'] <=> b['resource_db_id']}
  end

  def output_file(export_directory)
    File.join(export_directory, @output_filename)
  end
end
