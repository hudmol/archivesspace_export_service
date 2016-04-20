require 'date'

class Job

  attr_reader :name, :id

  def initialize(params)
    @id = params.fetch(:job_identifier)
    @name = params.fetch(:job_name)

    @task = params.fetch(:task)
    @params = params.fetch(:task_parameters)
  end

  def task
    @task.new(@params)
  end

  def within_window?(time)
    raise NotImplementedError.new("Implement me")
  end

end

