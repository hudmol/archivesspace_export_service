require_relative 'xml_exception'
require 'saxon-xslt'

class XSLTProcessor

  class TransformError < XMLException
  end

  def initialize(xslt_file)
    begin
      @transformer = Saxon.XSLT(File.open(xslt_file), system_id: File.absolute_path(xslt_file))
    rescue
      raise TransformError.new("XSLT transform failed to load", $!)
    end
  end

  def transform(identifier, input_file, output_file)
    begin
      temp_output = "#{output_file}.tmp"
      ead = Saxon.XML(File.read(input_file))
      result = @transformer.apply_to(ead)

      File.open(temp_output, 'w') do |file|
        file.write(result)
      end
    rescue
      File.delete(temp_output) rescue nil
      raise TransformError.new("XSLT transform failed for record #{identifier}", $!)
    end

    File.rename(temp_output, output_file)
  end

end
