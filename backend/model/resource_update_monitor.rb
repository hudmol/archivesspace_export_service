class ResourceUpdateMonitor

  def initialize()
  end

  def updates_since(timestamp)
    adds = []
    removes = []
    mtime = Time.at(timestamp.to_i)
    DB.open do |db|
      mods = db[:resource].where(Sequel.qualify(:resource, :system_mtime) > mtime)
        .select(:id, :identifier, :publish, :suppressed)

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
        removes << res[:uri].split('/')[-1]
      end

    end


    {'timestamp' => timestamp, 'adds' => adds, 'removes' => removes}
  end

end
