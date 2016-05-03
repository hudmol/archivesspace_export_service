class JobDefinitions

  def initialize(config)
    @config = config

    job_ids = @config[:jobs].map(&:id)

    unless job_ids.sort == job_ids.uniq.sort
      raise "You have two job definitions with the same identifier!  Job IDs must be unique."
    end

    job_ids.each do |id|
      if id =~ /[^A-Za-z0-9_\-\.]/
        raise "Job identifiers can only contain letters, numbers, underscores, dashes and dots"
      end
    end
  end

  def self.parse_config(config_file)
    new(eval(File.read(config_file)))
  end

  def each(&block)
    @config.fetch(:jobs).each(&block)
  end

end
