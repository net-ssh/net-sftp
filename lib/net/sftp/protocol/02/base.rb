require 'net/sftp/protocol/01/base'

module Net; module SFTP; module Protocol; module V02

  class Base < V01::Base

    def rename(name, new_name, flags=nil)
      send_request(FXP_RENAME, :string, name, :string, new_name)
    end

  end

end; end; end; end
