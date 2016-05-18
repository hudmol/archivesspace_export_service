require 'date'

class Job

  attr_reader :name, :id, :before_hooks, :after_hooks

  def initialize(params)
    @id = params.fetch(:identifier)

    @workspace_base = ExporterApp.workspace_for_job(@id)

    @before_hooks = params.fetch(:before_hooks, [])
    @after_hooks = params.fetch(:after_hooks, [])

    @task = params.fetch(:task)
    @task_params = params.fetch(:task_parameters)
  end

  def task
    @task.new(@task_params, @id, @workspace_base)
  end

  def within_window?(time)
    raise NotImplementedError.new("Implement me")
  end

  def to_s
    "Job: #{@id} - #{@task}"
  end
end

