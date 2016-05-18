require 'erb'
require_relative 'hook_interface'

class FopPdfGenerator < HookInterface

  def initialize(xslt_file)
    @xslt_file = File.absolute_path(xslt_file)
  end

  def call(task)
    export_directory = task.exported_variables.fetch(:export_directory)
    subdirectory = task.exported_variables.fetch(:subdirectory)

    full_export_path = File.join(export_directory, subdirectory)

    json_files(full_export_path).each do |json_file|
      json = JSON.parse(File.read(json_file))

      ead_file =  File.join(full_export_path, json.fetch('ead_file'))
      identifier = File.basename(ead_file, '.*')
      fop_file = File.join(full_export_path, "#{identifier}.fop")
      pdf_file = File.join(full_export_path, "#{identifier}.pdf")
      pdf_tmp_file = "#{pdf_file}.tmp"

      if File.exist?(pdf_file) && File.mtime(ead_file) < File.mtime(pdf_file)
        # PDF doesn't need updating
        next
      end

      XSLTProcessor.new(@xslt_file).transform(identifier, ead_file, fop_file)

      output_stream = java.io.FileOutputStream.new(pdf_tmp_file)

      begin
        input_stream = java.io.FileInputStream.new(fop_file)

        fop_factory = org.apache.fop.apps.FopFactory.newInstance
        fop_factory.setBaseURL("file://#{File.dirname(@xslt_file)}")
        fop_factory.setFontBaseURL("file://#{ExporterApp.base_dir('config/fonts')}")

        fop = fop_factory.newFop(org.apache.fop.apps.MimeConstants::MIME_PDF, output_stream)

        agent = org.apache.fop.apps.FOUserAgent.new(fop_factory)
        agent.setTitle(json.fetch('title'))
        agent.setCreationDate(File.mtime(ead_file).to_java(java.util.Date))

        fop = fop_factory.newFop(org.apache.fop.apps.MimeConstants::MIME_PDF, agent, output_stream)
        transformer = javax.xml.transform.TransformerFactory.newInstance.newTransformer
        res = javax.xml.transform.sax.SAXResult.new(fop.getDefaultHandler)
        transformer.transform(javax.xml.transform.stream.StreamSource.new(input_stream), res)
      ensure
        output_stream.close
        File.delete(fop_file)
      end

      File.rename(pdf_tmp_file, pdf_file)
    end
  end

  def json_files(path)
    Dir.glob(File.join(path, "*.json"))
  end
end
