class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/resource-update-feed')
    .description("Get a list of IDs for Resources changed since a timestamp")
    .params(["timestamp", String, "Timestamp of last update"])
    .permissions([])
    .returns([200, "{adds:[IDs],removes:[IDs]}"]) \
  do
    monitor = ResourceUpdateMonitor.new
    json_response(monitor.updates_since(params[:timestamp]))
  end

end
