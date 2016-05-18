require 'tempfile'
require_relative 'task_utils'
require_relative 'xml_exception'
require_relative 'xslt_processor'

class SchematronValidator

  class ValidationFailedException < XMLException
  end

  def initialize(schema_file)
    @log = ExporterApp.log_for(self.class.to_s)
    @schema_file = schema_file
    @schematron_schema = Tempfile.new

    XSLTProcessor.new(File.join(File.dirname(__FILE__), 'schematron-xsl/iso_dsdl_include.xsl'))
      .transform('schematron_001', schema_file, @schematron_schema.path)

    XSLTProcessor.new(File.join(File.dirname(__FILE__), 'schematron-xsl/iso_abstract_expand.xsl'))
      .transform('schematron_002', @schematron_schema.path, @schematron_schema.path)

    XSLTProcessor.new(File.join(File.dirname(__FILE__), 'schematron-xsl/iso_svrl_for_xslt2.xsl'))
      .transform('schematron_003', @schematron_schema.path, @schematron_schema.path)
  end

  def validate(identifier, file_to_validate)
    validation_result = Tempfile.new

    XSLTProcessor.new(@schematron_schema.path)
      .transform('schematron_check', file_to_validate, validation_result.path)

    report = File.read(validation_result.path)

    if report =~ /<svrl:failed-assert/
      raise ValidationFailedException.new("Schematron validation failed for #{identifier}:\n#{report}\n")
    else
      @log.info("Record #{identifier} successfully validated against #{File.basename(@schema_file)}")
    end
  end

end
