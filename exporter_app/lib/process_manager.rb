class ProcessManager

  def initialize
    @processes_by_job = {}
  end

  def start_job(job, completed_callback)
    process = Process.new(job, completed_callback)
    @processes_by_job[job] = process
    process.call
  end

  def shutdown
    @processes_by_job.each do |job, process|
      process.terminate!
    end
  end


  class Process

    # THINKME: Maybe we don't need the ability to terminate from the outside like this?
    def initialize(job, completed_callback)
      @job = job
      @callback = completed_callback
      @should_terminate = java.util.concurrent.atomic.AtomicBoolean.new(false)
      @thread = :worker_not_started
      @log = ExporterApp.log_for(@job.id)
      @log.info("Initialized")
    end

    def call
      @thread = Thread.new do
        begin
          @log.info("Running")
          status = JobStatus::COMPLETED

          @job.before_hooks.each do |hook|
            hook.call(@job.task)
          end

          begin
            @job.task.call(self)

            @job.after_hooks.each do |hook|
              hook.call(@job.task)
            end
          rescue
            @log.error($!)
            @log.error($@.join("\n"))
            status = JobStatus::FAILED
          ensure
            begin
              status = terminated? ? JobStatus::TERMINATED : status

              # THINKME: This callback happens on a different thread
              @callback.call(@job, status)
            rescue
              @log.error($!)
              @log.error($@.join("\n"))
            end
          end
        rescue
          @log.error($!)
          @log.error($@.join("\n"))
        end
      end
    end

    def running?
      !@job.should_stop?(Time.now) && !terminated?
    end

    def terminate!
      @should_terminate.set(true)
      @thread.join unless @thread == :worker_not_started
    end

    def terminated?
      @should_terminate.get
    end
  end

end
