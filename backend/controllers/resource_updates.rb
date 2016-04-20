class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/resource-update-feed')
    .description("Get a list of IDs for Resources changed since a timestamp")
    .params(["timestamp", String, "Timestamp of last update"],
            ["repo_id", Integer, "Repository ID", :optional => true])
    .permissions([])
    .returns([200, "{adds:[{'id':ID,'identifier':FOURPART},...],removes:[IDs]}"]) \
  do
    monitor = ResourceUpdateMonitor.new
    monitor.repo_id(params[:repo_id]) if params[:repo_id]
    json_response(monitor.updates_since(params[:timestamp]))
  end

end
