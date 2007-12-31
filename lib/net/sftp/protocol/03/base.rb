require 'net/sftp/protocol/02/base'

module Net; module SFTP; module Protocol; module V03

  class Base < V02::Base

    def version
      3
    end

    def readlink(path)
      send_request(FXP_READLINK, :string, path)
    end

    def symlink(path, target)
      send_request(FXP_SYMLINK, :string, path, :string, target)
    end

  end

end; end; end; end