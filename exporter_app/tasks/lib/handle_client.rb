require 'net/http'
require 'net/https'

class HandleClient

  def initialize(wsdl_url, user, credential, prefix, group, handle_base = 'http://hdl.handle.net')
    @wsdl_url = wsdl_url
    @user = user
    @credential = credential
    @prefix = prefix
    @group = group
    @handle_base = handle_base
  end

  def create_handle(id)
    [@handle_base, @prefix, id].join('/')
  end
end
