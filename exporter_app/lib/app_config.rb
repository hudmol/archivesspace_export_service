class AppConfig

  def initialize(config)
    @config = config
  end

  def [](key)
    @config.fetch(key)
  end

  def self.load(file)
    new(eval(File.open(file).read))
  end
end
