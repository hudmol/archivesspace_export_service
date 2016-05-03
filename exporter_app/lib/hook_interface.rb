class HookInterface
  def call(task)
    raise NotImplementedError.new("Subclass must implement this")
  end
end