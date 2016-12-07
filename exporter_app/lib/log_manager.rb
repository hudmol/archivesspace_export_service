require 'fileutils'
require 'logger'

class LogManager

  attr_reader :log_file

  def initialize
    log_dir = ExporterApp.base_dir("logs")
    FileUtils.mkdir_p(log_dir)
    @log_file = File.join(log_dir, "exporter_app.out")
    @log = Logger.new(@log_file)
    level = ExporterApp.config[:log_level]
    @log.level = Kernel.const_get("Logger::#{level.upcase}")
  end

  def log_for(progname = nil)
    Log.new(@log, progname)
  end


  class Log

    def initialize(log, progname)
      @log = log
      @progname = thread_name + (progname ? (':' + progname) : '')
    end

    def alert(message)
      @log.error(@progname) { message }
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

    private

    def thread_name
      Thread.current['name'] || Thread.current.to_s
    end

  end

end

