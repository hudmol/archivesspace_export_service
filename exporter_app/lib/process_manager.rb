class ProcessManager

  def initialize
    @processes_by_job = {}
    @log = ExporterApp.log_for("ProcessManager")
  end

  def start_job(job, completed_callback)
    @log.debug("Starting #{job}")
    process = Process.new(job, completed_callback)
    @processes_by_job[job] = process
    process.call
  end

  def shutdown
    @log.info("Shutting down")
    @processes_by_job.each do |job, process|
      process.terminate!
    end
  end


  class Process

    def initialize(job, completed_callback)
      @job = job
      @callback = completed_callback
      @should_terminate = java.util.concurrent.atomic.AtomicBoolean.new(false)
      @thread = :worker_not_started
      @log = ExporterApp.log_for
    end

    def call
      @thread = Thread.new do
        log = ExporterApp.log_for

        begin
          Thread.current['name'] = "Job #{@job.id} (#{@job.task.class}) - #{Thread.current.to_s}@#{Thread.current.object_id}"

          log.info("Running")
          status = JobStatus::COMPLETED

          log.debug("Running before hooks")
          @job.before_hooks.each do |hook|
            hook.call(@job.task)
          end

          begin
            log.debug("Running main task")
            @job.task.call(self)

            log.debug("Running after hooks")
            @job.after_hooks.each do |hook|
              hook.call(@job.task)
            end

            @job.task.completed!
          rescue
            log.error($!)
            log.error($@.join("\n"))
            status = JobStatus::FAILED
          ensure
            begin
              status = terminated? ? JobStatus::TERMINATED : status

              # NOTE: This callback happens on a different thread to the task itself
              @callback.call(@job, status)
            rescue
              log.error($!)
              log.error($@.join("\n"))
            end
          end
        rescue
          log.error($!)
          log.error($@.join("\n"))
        end
      end
    end

    def running?
      !@job.should_stop?(Time.now) && !terminated?
    end

    def terminate!
      @log.info("I've been terminated :(")
      @should_terminate.set(true)
      @thread.join unless @thread == :worker_not_started
    end

    def terminated?
      @should_terminate.get
    end
  end

end
