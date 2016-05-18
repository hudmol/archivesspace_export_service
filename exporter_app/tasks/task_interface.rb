class TaskInterface

  def initialize(params)
    raise NotImplementedError.new("Subclass must implement this")
  end

  def call(process)
    raise NotImplementedError.new("Subclass must implement this")
  end

  def exported_variables
    raise NotImplementedError.new("Subclass must implement this")
  end

  def completed!
    # Optional...
  end

end
