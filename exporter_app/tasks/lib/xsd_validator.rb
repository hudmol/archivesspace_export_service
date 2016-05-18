require_relative 'task_utils'
require_relative 'xml_exception'

class XSDValidator

  class ValidationFailedException < XMLException
  end

  def initialize(schema_file)
    @log = ExporterApp.log_for(self.class.to_s)
    @schema_file = schema_file
    schema_factory = javax.xml.validation.SchemaFactory.new_instance(javax.xml.XMLConstants::W3C_XML_SCHEMA_NS_URI)

    source = TaskUtils.http_url?(schema_file) ? java.net.URL.new(schema_file) : java.io.File.new(schema_file)
    schema = schema_factory.new_schema(source)

    @validator = schema.new_validator
  end

  def validate(identifier, file_to_validate)
    source = javax.xml.transform.stream.StreamSource.new(java.io.File.new(file_to_validate))
    begin
      @validator.validate(source)
      @log.info("Record #{identifier} successfully validated against #{File.basename(@schema_file)}")
    rescue
      raise ValidationFailedException.new("Validation failed for record #{identifier}", $!)
    end
  end

end
