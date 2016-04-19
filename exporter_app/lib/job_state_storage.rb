class JobStateStorage

  class JobState < Struct.new(:last_start_time, :last_finish_time, :status)

    def running?
      status == 'running'
    end

  end

  def initialize
    # FIXME: When this gets created:
    #  - find anything with a status of 'running'
    #
    #  - delete them from the storage?  Seems like we want them to run again if
    #    we're still within the window...

    @store = {}
  end

  def job_started(job)
    @store[job] = JobState.new(Time.now, nil, 'running')
  end

  def job_completed(job, status)
    job_info = @store.fetch(job)

    job_info.last_finish_time = Time.now
    job_info.status = status
  end

  def last_run_of(job)
    @store.fetch(job, null_job_info)
  end

  private

  def null_job_info
    JobState.new(Time.at(0), Time.at(0), 'never_started')
  end

end
