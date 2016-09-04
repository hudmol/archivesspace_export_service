class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/resource-update-feed')
    .description("Get a list of IDs for Resources changed since a timestamp")
    .params(["timestamp", Integer, "Timestamp of last update (seconds since epoch)"],
            ["repo_id", Integer, "Repository ID", :optional => true],
            ["start_id", String, "Four-part identifier as a JSON array specifying the start of a range", :optional => true],
            ["end_id", String, "Four-part identifier as a JSON array specifying the end of a range", :optional => true],
            )
    .permissions([])
    .returns([200, "{adds:[{'id':ID,'identifier':FOURPART},...],removes:[IDs]}"]) \
  do
    monitor = ResourceUpdateMonitor.new
    monitor.repo_id(params[:repo_id]) if params[:repo_id]
    monitor.identifier(params[:start_id], params[:end_id]) if params[:start_id] || params[:end_id]
    json_response(monitor.updates_since(params[:timestamp]))
  end

end
