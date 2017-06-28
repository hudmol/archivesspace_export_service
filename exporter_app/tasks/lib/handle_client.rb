require 'savon'

class HandleClient

  HANDLE_HOST = 'http://hdl.handle.net'

  def initialize(wsdl_url, user, credential, prefix, group, handle_base)
    @wsdl_url = wsdl_url
    @user = user
    @credential = credential
    @prefix = prefix
    @group = group
    @handle_base = handle_base

    # looks like the namespace stuff from the example code isn't required
    # leaving it commented for now in case it is needed later
    # @namespace = @prefix.sub(/.*?\//, '') + ':'

    @client = Savon.client(wsdl: @wsdl_url)
  end

  def create_handle(id, uri)
    # unless id.include?(@namespace)
    #   raise "Handle prefix namespace '#{@namespace}' doesn't match namespace of id '#{id}'"
    # end
    # handle = [@prefix, id.sub(@namespace, '')].join('/')

    handle = [@prefix, id].join('/')

    response = @client.call(:create_batch_semantic, xml: soap_envelope(handle, uri))

    unless response.success?
      raise "Failed to create handle for id '#{id}' with uri '#{uri}': #{response.to_xml.to_s}"
    end

    [HANDLE_HOST, handle].join('/')
  end

  private

  def soap_envelope(handle, uri)
    <<-EOT
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Body>
    <tns:createBatchSemantic xmlns:tns="http://ws.ypls.its.yale.edu/">
      <handlesToValues>
        <map>
          <entry>
            <key>#{handle}</key>
            <value>#{@handle_base}#{uri}</value>
          </entry>
        </map>
      </handlesToValues>
      <group>#{@group}</group>
      <user>#{@user}</user>
      <credential>#{@credential}</credential>
    </tns:createBatchSemantic>
  </env:Body>
</env:Envelope>
EOT
  end
 
end
