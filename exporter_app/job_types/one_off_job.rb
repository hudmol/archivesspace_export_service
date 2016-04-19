class OneOffJob < Job

  def initialize(params)
    super
  end

  def should_run?(*)
    false
  end

end
