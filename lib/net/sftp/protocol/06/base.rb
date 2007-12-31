require 'net/sftp/protocol/05/base'
require 'net/sftp/protocol/06/attributes'

module Net; module SFTP; module Protocol; module V06

  class Base < V05::Base

    def version
      6
    end

    def link(new_link_path, existing_path, symlink)
      send_request(FXP_LINK, :string, new_link_path, :string, existing_path, :bool, symlink)
    end

    def symlink(path, target)
      link(target, path, true)
    end

    def block(handle, offset, length, mask)
      send_request(FXP_BLOCK, :string, handle, :int64, offset, :int64, length, :long, mask)
    end

    def unblock(handle, offset, length)
      send_request(FXP_UNBLOCK, :string, handle, :int64, offset, :int64, length)
    end

    protected

      def attribute_factory
        V06::Attributes
      end
  end

end; end; end; end