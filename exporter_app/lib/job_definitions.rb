class JobDefinitions

  def initialize(config)
    @config = config
  end

  def self.parse_config(config_file)
    new(eval(File.read(config_file)))
  end

  def each(&block)
    @config.fetch(:jobs).each(&block)
  end

end
