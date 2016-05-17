require 'uri'

class TaskUtils

  def self.http_url?(s)
    ['https', 'http'].include?(URI.parse(s).scheme)
  end

end
