require 'net/http'
require 'json'

class ResourceUpdateFeed

  def initialize(aspace_backend_url, username, password)
    @aspace_backend_url = aspace_backend_url
    @username = username
    @password = password

    @session = login
  end

  def updates_since(epoch_time)
    raise json_get('/resource-update-feed', :timestamp => epoch_time).inspect
  end

  private

  def login
    json_post("/users/#{@username}/login", :password => @password, :expiring => false)['session']
  end

  def json_post(uri, params)
    response = Net::HTTP.post_form(URI.join(@aspace_backend_url, uri), params)

    if response.code != '200'
      raise "#{response.code}: #{response.body}"
    end

    JSON(response.body)
  end

  def json_get(uri, params)
    uri = URI.join(@aspace_backend_url, uri)
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.code != '200'
      raise "#{response.code}: #{response.body}"
    end

    JSON(response.body)
  end

end
