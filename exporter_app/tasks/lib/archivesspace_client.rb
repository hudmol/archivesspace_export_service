require 'net/http'
require 'net/https'
require 'json'

class ArchivesSpaceClient

  def initialize(aspace_backend_url, username, password)
    @aspace_backend_url = aspace_backend_url
    @aspace_backend_path = "#{URI(@aspace_backend_url).path}/".gsub(/\/+$/,"/")
    @username = username
    @password = password

    @session
  end

  def updates_since(epoch_time, opts = {})
    json_get('/resource-update-feed', opts.merge(:timestamp => epoch_time))
  end

  def export(id, repo_id, opts = {})
    get("/repositories/#{repo_id}/resource_descriptions/#{id}.xml", opts)
  end

  def update_record(uri, hash)
    json_post(uri, json_get(uri).merge(hash), true)
  end

  private

  def login
    json_post("/users/#{@username}/login", :password => @password, :expiring => false)['session']
  end

  def json_post(path, params, body = false)
    uri = URI.join(@aspace_backend_url, @aspace_backend_path, path.gsub(/^\//,""))

    request = Net::HTTP::Post.new(uri)
    request['X-ArchivesSpace-Session'] = @session if @session

    if body
      request['Content-Type'] = 'text/json'
      request.body = JSON.generate(params)
    else
      request.form_data = params
    end

    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == 'https'
      http.use_ssl = true
    end

    response = http.start {|http| http.request(request) }

    if response.code != '200'
      raise "#{response.code}: #{response.body}"
    end

    JSON(response.body)
  end

  def get(path, params)
    @session = login unless @session

    uri = URI.join(@aspace_backend_url, @aspace_backend_path, path.gsub(/^\//,""))
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)

    http.read_timeout = 600
    http.open_timeout = 600

    if uri.scheme == 'https'
      http.use_ssl = true
    end

    request = Net::HTTP::Get.new(uri)
    request['X-ArchivesSpace-Session'] = @session

    response = http.start {|http| http.request(request) }

    if response.code != '200'
      raise "#{response.code}: #{response.body}"
    end

    response.body
  end

  def json_get(uri, params = {})
    JSON(get(uri, params))
  end
end
