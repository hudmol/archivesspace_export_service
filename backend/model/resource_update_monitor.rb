class ResourceUpdateMonitor

  def initialize()
    @repo_id = nil
    @start_id = nil
    @end_id = nil
  end


  def repo_id(repo_id)
    @repo_id = repo_id
  end


  def identifier(start_id, end_id = nil)
    @start_id = start_id
    @end_id = end_id
  end


  def updates_since(timestamp)
    adds = []
    removes = []
    mtime = Time.at(timestamp.to_i)
    DB.open do |db|
      mods = db[:resource].where(Sequel.qualify(:resource, :system_mtime) > mtime)

      if @repo_id
        mods = mods.where(:repo_id => @repo_id)
      end

      if @start_id
        mods = mods.where(:identifier => @start_id)
      end

      mods = mods.select(:id, :identifier, :publish, :suppressed)

      mods.each do |res|
        if res[:publish] == 1 && res[:suppressed] == 0
          adds << {'id' => res[:id], 'identifier' => JSON.parse(res[:identifier])}
        else
          removes << res[:id]
        end
      end

      dels = db[:deleted_records].where(Sequel.qualify(:deleted_records, :timestamp) > mtime)
        .select(:uri)

      dels.each do |res|
        ref = JSONModel.parse_reference(res[:uri])
        if @repo_id
          repo = JSONModel.parse_reference(ref[:repository])
          removes << ref[:id] if @repo_id == repo[:id]
        else
          removes << ref[:id]
        end
      end

    end

    {'timestamp' => timestamp, 'adds' => adds, 'removes' => removes}
  end

end
