class ExporterApp

  POLL_INTERVAL = 60

  def self.main

    # Load everything
    ["lib", "job_types", "tasks"].each do |dir|
      Dir.glob(base_dir("#{dir}/*.rb")).each do |file|
        require(File.absolute_path(file))
      end
    end

    job_definitions = JobDefinitions.from_config(base_dir("config/jobs.rb"))

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
                                      job_state_storage.dump
                                    })

        else
          puts "Not time to run #{job}"
        end
      end

      puts "Sleeping #{POLL_INTERVAL} seconds"
      sleep POLL_INTERVAL
    end

  end

  def self.config
    AppConfig.load(base_dir("config/config.rb"))
  end


  def self.base_dir(path = nil)
    base = File.dirname(__FILE__)

    if path
      File.join(base, path)
    else
      base
    end
  end


  def self.workspace_for_job(job_id)
    File.absolute_path(base_dir("workspace/#{job_id}"))
  end

end


ExporterApp.main
