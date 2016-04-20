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

    def initialize(job, completed_callback)
      @job = job
      @callback = completed_callback
      @should_terminate = java.util.concurrent.atomic.AtomicBoolean.new(false)
      @thread = :worker_not_started
    end

    def call
      @thread = Thread.new do
        status = 'completed'

        begin
          @job.task.call(self)
        rescue
          $stderr.puts($!)
          $stderr.puts($@.join("\n"))
          status = 'failed'
        ensure
          begin
            status = terminated? ? 'terminated' : status

            # THINKME: This callback happens on a different thread
            @callback.call(@job, status)
          rescue
            $stderr.puts($!)
            $stderr.puts($@.join("\n"))
          end
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
