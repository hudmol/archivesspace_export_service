require 'manticore'
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

    headers = {}

    if @session
      headers['X-ArchivesSpace-Session'] = @session
    end

    response = if body
                 Manticore.post(uri.to_s, params: params, headers: headers.merge('Content-Type' => 'text/json'), body: body)
               else
                 Manticore.post(uri.to_s, params: params, headers: headers)
               end

    if response.code != 200
      raise "#{response.code}: #{response.body}"
    end

    JSON(response.body)
  end

  def get(path, params)
    @session = login unless @session

    uri = URI.join(@aspace_backend_url, @aspace_backend_path, path.gsub(/^\//,""))

    response = Manticore.get(uri.to_s,
                             query: params,
                             headers: { 'X-ArchivesSpace-Session' => @session },
                             :connect_timeout => 600.0,
                             :socket_timeout => 600.0,
                             :request_timeout => 600.0)

    if response.code != 200
      raise "#{response.code}: #{response.body}"
    end

    response.body
  end

  def json_get(uri, params = {})
    JSON(get(uri, params))
  end
end
