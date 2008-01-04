require 'net/sftp/protocol/03/base'
require 'net/sftp/protocol/04/attributes'
require 'net/sftp/protocol/04/name'

module Net; module SFTP; module Protocol; module V04

  class Base < V03::Base

    def version
      4
    end

    # Same as earlier versions, except the longname member was removed.
    def parse_name_packet(packet)
      names = []

      packet.read_long.times do
        filename = packet.read_string
        attrs    = attribute_factory.from_buffer(packet)
        names   << name_factory.new(filename, attrs)
      end

      { :names => names }
    end

    def stat(path, flags=nil)
      send_request(FXP_STAT, :string, path, :long, convert(flags))
    end

    def lstat(path, flags=nil)
      send_request(FXP_LSTAT, :string, path, :long, convert(flags))
    end

    def fstat(handle, flags=nil)
      send_request(FXP_FSTAT, :string, handle, :long, convert(flags))
    end

    protected

      DEFAULT_FLAGS = Attributes::F_SIZE |
                      Attributes::F_PERMISSIONS |
                      Attributes::F_ACCESSTIME |
                      Attributes::F_CREATETIME |
                      Attributes::F_MODIFYTIME |
                      Attributes::F_ACL |
                      Attributes::F_OWNERGROUP |
                      Attributes::F_SUBSECOND_TIMES |
                      Attributes::F_EXTENDED

      def convert(flags)
        flags ||= DEFAULT_FLAGS
      end

      def attribute_factory
        V04::Attributes
      end

      def name_factory
        V04::Name
      end
  end

end; end; end; end