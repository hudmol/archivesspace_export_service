##
# Do nothing.  In a loop.
class SleepTask

  def initialize(params)
    @params = params

    @log = ExporterApp.log_for("SleepyHead")
  end

  def call(process)
    5.times do
      if !process.running?
        @log.error("Job stopped! #{Thread.current}")
        break
      end

      @log.debug("Loop")
      sleep 1
    end
  end

end
