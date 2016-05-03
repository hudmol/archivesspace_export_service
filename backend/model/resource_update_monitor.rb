class ResourceUpdateMonitor

  include JSONModel

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
    @parsed_start_id = JSON.parse(@start_id)
    @id_range = []
    if @end_id
      @parsed_end_id = JSON.parse(@end_id)
      @parsed_start_id.each_index do |ix|
        if @parsed_start_id[ix] && @parsed_end_id[ix]
          if @parsed_start_id[ix] < @parsed_end_id[ix]
            @id_range << {:low => @parsed_start_id[ix], :hi => @parsed_end_id[ix], :skip => false}
          else
            @id_range << {:hi => @parsed_start_id[ix], :low => @parsed_end_id[ix], :skip => false}
          end
        else
          @id_range << {:skip => true}
        end
      end
    end
  end


  def in_range(resource)
    return true unless @start_id && @end_id

    res_id = JSON.parse(resource[:identifier])

    res_id.each_index do |ix|
      next if @id_range[ix][:skip]
      return false unless res_id[ix]
      return false if res_id[ix] < @id_range[ix][:low] || res_id[ix] > @id_range[ix][:hi]
    end

    return true
  end


  def updates_since(timestamp)
    adds = []
    removes = []
    mtime = Time.at(timestamp)
    DB.open do |db|
      mods = db[:resource].where(Sequel.qualify(:resource, :system_mtime) > mtime)

      if @repo_id
        mods = mods.where(:repo_id => @repo_id)
      end

      if @start_id && !@end_id
        mods = mods.where(:identifier => @start_id)
      end

      mods = mods.select(:id, :title, :identifier, :repo_id, :publish, :suppressed)

      mods.each do |res|
        if in_range(res)
          if res[:publish] == 1 && res[:suppressed] == 0
            adds << {
              'id' => res[:id],
              'title' => res[:title],
              'identifier' => JSON.parse(res[:identifier]),
              'repo_id' => res[:repo_id],
              'uri' => JSONModel(:resource).uri_for(res[:id], :repo_id => res[:repo_id]),
            }
          else
            removes << res[:id]
          end
        end
      end

      dels = db[:deleted_records].where(Sequel.qualify(:deleted_records, :timestamp) > mtime)
        .select(:uri)

      dels.each do |res|
        ref = JSONModel.parse_reference(res[:uri])
        if ref[:type] == 'resource'
          if @repo_id
            repo = JSONModel.parse_reference(ref[:repository])
            removes << ref[:id] if @repo_id == repo[:id]
          else
            removes << ref[:id]
          end
        end
      end

    end

    {'timestamp' => timestamp, 'adds' => adds, 'removes' => removes}
  end

end
