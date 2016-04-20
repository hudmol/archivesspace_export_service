##
# Do nothing.  In a loop.
class SleepTask

  def initialize(params)
    @params = params
  end

  def call(process)
    5.times do
      if !process.running?
        $stderr.puts "Job stopped! #{Thread.current}"
        break
      end

      puts "Loop"
      sleep 1
    end
  end

end
