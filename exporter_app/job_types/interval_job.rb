class IntervalJob < Job

  def initialize(params)
    super

    @interval_minutes = params.fetch(:interval_minutes)
  end

  def should_run?(*)
    false
  end

end
