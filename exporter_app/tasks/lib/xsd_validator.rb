require_relative 'xml_exception'

class XSDValidator

  class ValidationFailedException < XMLException
  end

  def initialize(schema_file)
    schema_factory = javax.xml.validation.SchemaFactory.new_instance(javax.xml.XMLConstants::W3C_XML_SCHEMA_NS_URI)
    schema = schema_factory.new_schema(java.io.File.new(schema_file))

    @validator = schema.new_validator
  end

  def validate(identifier, file_to_validate)
    source = javax.xml.transform.stream.StreamSource.new(java.io.File.new(file_to_validate))
    begin
      @validator.validate(source)
    rescue
      raise ValidationFailedException.new("Validation failed for record #{identifier}", $!)
    end
  end

end
