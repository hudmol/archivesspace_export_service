class WeekdayJob < Job

  class TimeRange
    def initialize(start_time_str, end_time_str)
      @start_time = normalize(start_time_str)
      @end_time = normalize(end_time_str)
    end

    def include?(time)
      normalized_time = time.strftime('%H%M')

      if @start_time <= @end_time
        @start_time <= normalized_time && normalized_time < @end_time
      else
        (@start_time <= normalized_time && normalized_time <= '2400') ||
          ('0000' <= normalized_time && normalized_time < @end_time)
      end
    end

    private

    def normalize(s)
      s.gsub(':', '').rjust(4, '0')
    end
  end


  def initialize(params)
    super

    @time_range = TimeRange.new(params.fetch(:start_time), params.fetch(:end_time))
    @days_of_week = params.fetch(:days_of_week).map(&:upcase)
  end

  def should_run?(now, last_run_info)
    # If the current time is within our window and we haven't already run the job today...
    @time_range.include?(now) &&
      @days_of_week.include?(weekday_of(now)) &&
      (last_run_info.last_start_time.to_date != now.to_date)
  end


  def should_stop?(now)
    !@time_range.include?(now)
  end


  private

  def weekday_of(time)
    time.strftime('%^a')
  end

end
