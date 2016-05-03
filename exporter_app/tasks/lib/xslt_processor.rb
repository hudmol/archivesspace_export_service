require_relative 'xml_exception'

class XSLTProcessor

  class TransformError < XMLException
  end

  def initialize(xslt_file)
    factory = javax.xml.transform.TransformerFactory.new_instance

    begin
      @transformer = factory.new_transformer(javax.xml.transform.stream.StreamSource.new(java.io.File.new(xslt_file)))
    rescue
      raise TransformError.new("XSLT transform failed to load", $!)
    end
  end

  def transform(identifier, input_file, output_file)
    temp_output = "#{output_file}.tmp"

    begin
      @transformer.transform(javax.xml.transform.stream.StreamSource.new(java.io.File.new(input_file)),
                             javax.xml.transform.stream.StreamResult.new(java.io.File.new(temp_output)))
    rescue
      raise TransformError.new("XSLT transform failed for record #{identifier}", $!)
    end

    File.rename(temp_output, output_file)
  end

end
