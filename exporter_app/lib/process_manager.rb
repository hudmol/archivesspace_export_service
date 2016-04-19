class ProcessManager

  def initialize
    @threads_by_job = {}
  end

  def start_job(job, completed_callback)
    process = Process.new(job, completed_callback)
    worker = Worker.new(process)

    worker.call

    @threads_by_job[job] = {process: process, worker: worker}
  end

  def shutdown
    @threads_by_job.each do |job, state|
      state[:process].terminate!
      state[:worker].join
    end
  end


  class Worker

    def initialize(process)
      @process = process
      @thread = :worker_not_started
    end

    def call
      @thread = Thread.new do
        status = 'completed'

        begin
          5.times do
            $stderr.puts "Worker running with ID: #{Thread.current} and job #{@process.job}"

            if @process.job.should_stop?(Time.now)
              $stderr.puts "Job stopped! #{Thread.current}"
              status = 'stopped'
              break
            end

            if @process.terminated?
              $stderr.puts "Worker told to terminate! #{Thread.current}"
              status = 'terminated'
              break
            end

            sleep 1
          end
        rescue
          $stderr.puts($!)
          $stderr.puts($@.join("\n"))
          status = 'failed'
        ensure
          begin
            # THINKME: This callback happens on a different thread
            @process.completed_callback.call(@process.job, status)
          rescue
            $stderr.puts($!)
            $stderr.puts($@.join("\n"))
          end
        end
      end
    end

    def join
      @thread.join unless @thread == :worker_not_started
    end

  end


  class Process
    attr_reader :job, :completed_callback

    def initialize(job, completed_callback)
      @job = job
      @completed_callback = completed_callback
      @should_terminate = java.util.concurrent.atomic.AtomicBoolean.new(false)
    end

    def terminate!
      @should_terminate.set(true)
    end

    def terminated?
      @should_terminate.get
    end
  end

end
