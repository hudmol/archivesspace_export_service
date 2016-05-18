require 'fileutils'
require 'logger'

class LogManager

  def initialize
    log_dir = ExporterApp.base_dir("logs")
    FileUtils.mkdir_p(log_dir)
    @log = Logger.new(File.join(log_dir, "exporter_app.out"))
    level = ExporterApp.config[:log_level]
    @log.level = Kernel.const_get("Logger::#{level.upcase}")
  end

  def log_for(progname)
    Log.new(@log, progname)
  end


  class Log

    def initialize(log, progname)
      @log = log
      @progname = progname
    end


    def error(message)
      @log.error(@progname) { message }
    end


    def info(message)
      @log.info(@progname) { message }
    end


    def debug(message)
      @log.debug(@progname) { message }
    end

  end

end

