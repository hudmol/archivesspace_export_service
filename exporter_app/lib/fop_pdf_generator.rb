require 'erb'
require_relative 'hook_interface'

class FopPdfGenerator < HookInterface

  def initialize(xslt_file)
    @xslt_file = File.absolute_path(xslt_file)
    @log = ExporterApp.log_for(self.class.to_s)
  end

  def call(task)
    export_directory = task.exported_variables.fetch(:export_directory)
    subdirectory = task.exported_variables.fetch(:subdirectory)

    full_export_path = File.join(export_directory, subdirectory)

    json_files(full_export_path).each do |json_file|
      begin
        json = JSON.parse(File.read(json_file))

        ead_file =  File.join(full_export_path, json.fetch('ead_file'))
        identifier = File.basename(ead_file, '.*')
        fop_file = File.join(full_export_path, "#{identifier}.fop")
        pdf_file = File.join(full_export_path, "#{identifier}.pdf")
        pdf_tmp_file = "#{pdf_file}.tmp"

        if File.exist?(pdf_file) && File.mtime(ead_file) <= File.mtime(pdf_file)
          # PDF doesn't need updating
          next
        end

        XSLTProcessor.new(@xslt_file).transform(identifier, ead_file, fop_file)

        output_stream = java.io.FileOutputStream.new(pdf_tmp_file)

        begin
          input_stream = java.io.FileInputStream.new(fop_file)

          builder = org.apache.fop.apps.FopFactoryBuilder.new(java.net.URI.new("file://#{File.dirname(@xslt_file)}"))

          config_builder = org.apache.avalon.framework.configuration.DefaultConfigurationBuilder.new
          config = config_builder.build(java.io.ByteArrayInputStream.new(generate_font_config.to_java.get_bytes("UTF-8")))

          builder.set_configuration(config)

          fop_factory = builder.build

          fop = fop_factory.newFop(org.apache.fop.apps.MimeConstants::MIME_PDF, output_stream)

          agent = fop_factory.newFOUserAgent
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
      rescue
        @log.error("There was a problem while producing a PDF for #{json_file}: #{$!}")
        @log.error("\n" + $@.join("\n") + "\n\n")
      end
    end
  end

  def json_files(path)
    Dir.glob(File.join(path, "*.json"))
  end

  private

  FONT_STYLES = {
    java.awt.Font::BOLD => 'bold',
    java.awt.Font::ITALIC => 'italic',
    java.awt.Font::PLAIN => 'normal',
  }

  def generate_font_config
    result = ("<?xml version=\"1.0\"?>" +
              "<fop>" +
              "  <renderers>" +
              "    <renderer mime=\"application/pdf\">" +
              "      <fonts>")

    Dir.glob(File.join(ExporterApp.base_dir("config/fonts"), "*.ttf")).each do |font_path|
      font_path = File.absolute_path(font_path)
      font = java.awt.Font.create_font(java.awt.Font::TRUETYPE_FONT, java.io.File.new(font_path))

      family = font.get_family
      style = FONT_STYLES.fetch(font.get_style, "normal")

      result += "<font kerning=\"yes\" embed-url=\"#{font_path}\" embedding-mode=\"subset\">"

      (50..1000).step(50).each do |weight|
        @log.info("Loaded font family=#{family} style=#{style} weight=#{weight}")
        result += "<font-triplet name=\"#{family}\" style=\"#{style}\" weight=\"#{weight}\"/>"
      end

      result += "</font>"
    end

    result += ("       </fonts>" +
               "    </renderer>" +
               "  </renderers>" +
               "</fop>")
  end
end
