require 'date'

class Job

  attr_reader :name, :id

  def initialize(params)
    @id = params.fetch(:job_identifier)
    @name = params.fetch(:job_name)
  end

  def within_window?(time)
    raise NotImplementedError.new("Implement me")
  end

end

