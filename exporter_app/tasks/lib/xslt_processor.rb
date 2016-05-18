require_relative 'task_utils'
require_relative 'xml_exception'

class XSLTProcessor

  class TransformError < XMLException
  end

  def initialize(xslt_source)
    factory = javax.xml.transform.TransformerFactory.new_instance("net.sf.saxon.TransformerFactoryImpl", nil)

    begin
      @transformer = factory.new_transformer(source_for(xslt_source))
    rescue
      raise TransformError.new("XSLT transform failed to load", $!)
    end
  end

  def transform(identifier, input_file, output_file)
    begin
      temp_output = "#{output_file}.tmp"

      @transformer.transform(javax.xml.transform.stream.StreamSource.new(java.io.File.new(input_file)),
                             javax.xml.transform.stream.StreamResult.new(java.io.File.new(temp_output)))

    rescue
      File.delete(temp_output) rescue nil
      raise TransformError.new("XSLT transform failed for record #{identifier}", $!)
    end

    File.rename(temp_output, output_file)
  end

  private

  def source_for(s)
    if TaskUtils.http_url?(s)
      is = java.net.URL.new(s).open_stream
      xslt = begin
               is.to_io.read
             ensure
               is.close
             end

      javax.xml.transform.stream.StreamSource.new(java.io.StringReader.new(xslt))
    else
      javax.xml.transform.stream.StreamSource.new(java.io.File.new(s))
    end
  end

end
