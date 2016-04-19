class ExporterApp

  POLL_INTERVAL = 60

  def self.main

    # Load everything
    ["lib", "job_types"].each do |dir|
      Dir.glob(base_dir("#{dir}/*")).each do |file|
        load(File.absolute_path(file))
      end
    end

    job_definitions = JobDefinitions.parse_config(base_dir("config/jobs.rb"))

    # SQLite?
    job_state_storage = JobStateStorage.new

    process_manager = ProcessManager.new

    # last start time, last complete time

    # Start the application's scheduling loop
    while true
      job_definitions.each do |job|
        now = Time.now

        last_run_info = job_state_storage.last_run_of(job)

        if job.should_run?(now, last_run_info) && !last_run_info.running?
          puts "Running #{job}!"
          # Start the job!
          job_state_storage.job_started(job)
          process_manager.start_job(job, proc { |job, status|
                                      # THINKME: This needs to be thread-safe
                                      job_state_storage.job_completed(job, status)
                                      $stderr.puts(job_state_storage.inspect)
                                    })

        else
          puts "Not time to run #{job}"
        end
      end

      puts "Sleeping #{POLL_INTERVAL} seconds"
      sleep POLL_INTERVAL
    end

  end

  def self.base_dir(path = nil)
    base = File.dirname(__FILE__)

    if path
      File.join(base, path)
    else
      base
    end
  end

end


ExporterApp.main
