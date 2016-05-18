class JobDefinitions

  def initialize(config_file)
    @config_file = config_file
    @log = ExporterApp.log_for(self.class.to_s)
  end

  def self.from_config(config_file)
    new(config_file)
  end

  def each(&block)
    parse_config.fetch(:jobs).each(&block)
  end

  private

  def parse_config
    begin
      config_string = File.read(@config_file)
      config = eval(config_string)

      job_ids = config[:jobs].map(&:id)

      unless job_ids.sort == job_ids.uniq.sort
	raise "You have two job definitions with the same identifier!  Job IDs must be unique."
      end

      job_ids.each do |id|
	if id =~ /[^A-Za-z0-9_\-\.]/
          raise "Job identifiers can only contain letters, numbers, underscores, dashes and dots"
	end
      end

      checkpoint_config(config_string)
      config
    rescue
      # Log a very obvious warning...
      @log.alert("\n\nINVALID CONFIGURATION -- could not read your #{File.basename(@config_file)} file -- #{$!}\n\n")
      load_checkpointed_config
    end
  end

  def checkpoint_file
    File.join(File.dirname(@config_file), '.' + File.basename(@config_file))
  end

  def checkpoint_config(config_contents)
    File.write(checkpoint_file, config_contents)
  end

  def load_checkpointed_config
    if File.exists?(checkpoint_file)
      begin
	@log.info("Running with previous valid configuration")
	return eval(File.read(checkpoint_file))
      rescue
	nil
      end
    end

    raise "No previous valid configuration exists!"
  end

end
