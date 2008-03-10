require 'net/ssh/loggable'
require 'net/sftp/constants'
require 'net/sftp/packet'
require 'net/sftp/protocol/base'
require 'net/sftp/protocol/01/attributes'
require 'net/sftp/protocol/01/name'

module Net; module SFTP; module Protocol; module V01

  class Base < Protocol::Base
    F_READ   = 0x00000001
    F_WRITE  = 0x00000002
    F_APPEND = 0x00000004
    F_CREAT  = 0x00000008
    F_TRUNC  = 0x00000010
    F_EXCL   = 0x00000020

    def version
      1
    end

    def parse_handle_packet(packet)
      { :handle => packet.read_string }
    end

    def parse_status_packet(packet)
      { :code => packet.read_long }
    end

    def parse_data_packet(packet)
      { :data => packet.read_string }
    end

    def parse_attrs_packet(packet)
      { :attrs => attribute_factory.from_buffer(packet) }
    end

    def parse_name_packet(packet)
      names = []

      packet.read_long.times do
        filename = packet.read_string
        longname = packet.read_string
        attrs    = attribute_factory.from_buffer(packet)
        names   << name_factory.new(filename, longname, attrs)
      end

      { :names => names }
    end

    def open(path, flags, options)
      flags = normalize_open_flags(flags)

      if    flags & IO::WRONLY != 0 then sftp_flags = F_WRITE
      elsif flags & IO::RDWR   != 0 then sftp_flags = F_READ | F_WRITE
      elsif flags & IO::APPEND != 0 then sftp_flags = F_APPEND
      else  sftp_flags = F_READ
      end

      sftp_flags |= F_CREAT if flags & IO::CREAT != 0
      sftp_flags |= F_TRUNC if flags & IO::TRUNC != 0
      sftp_flags |= F_EXCL  if flags & IO::EXCL  != 0

      attributes = attribute_factory.new(options)

      send_request(FXP_OPEN, :string, path, :long, sftp_flags, :raw, attributes.to_s)
    end

    def close(handle)
      send_request(FXP_CLOSE, :string, handle)
    end

    def read(handle, offset, length)
      send_request(FXP_READ, :string, handle, :int64, offset, :long, length)
    end

    def write(handle, offset, data)
      send_request(FXP_WRITE, :string, handle, :int64, offset, :string, data)
    end

    def lstat(path, flags=nil)
      send_request(FXP_LSTAT, :string, path)
    end

    def fstat(handle, flags=nil)
      send_request(FXP_FSTAT, :string, handle)
    end

    def setstat(path, attrs)
      send_request(FXP_SETSTAT, :string, path, :raw, attribute_factory.new(attrs).to_s)
    end

    def fsetstat(handle, attrs)
      send_request(FXP_FSETSTAT, :string, handle, :raw, attribute_factory.new(attrs).to_s)
    end

    def opendir(path)
      send_request(FXP_OPENDIR, :string, path)
    end

    def readdir(handle)
      send_request(FXP_READDIR, :string, handle)
    end

    def remove(filename)
      send_request(FXP_REMOVE, :string, filename)
    end

    def mkdir(path, attrs)
      send_request(FXP_MKDIR, :string, path, :raw, attribute_factory.new(attrs).to_s)
    end

    def rmdir(path)
      send_request(FXP_RMDIR, :string, path)
    end

    def realpath(path)
      send_request(FXP_REALPATH, :string, path)
    end

    def stat(path, flags=nil)
      send_request(FXP_STAT, :string, path)
    end

    def rename(name, new_name, flags=nil)
      not_implemented! :rename
    end

    def readlink(path)
      not_implemented! :readlink
    end

    def symlink(path, target)
      not_implemented! :symlink
    end

    def link(*args)
      not_implemented! :link
    end

    def block(handle, offset, length, mask)
      not_implemented! :block
    end

    def unblock(handle, offset, length)
      not_implemented! :unblock
    end

    protected

      def not_implemented!(operation)
        raise NotImplementedError, "the #{operation} operation is not available in the version of the SFTP protocol supported by your server"
      end

      def normalize_open_flags(flags)
        if String === flags
          case flags.tr("b", "")
          when "r"  then IO::RDONLY
          when "r+" then IO::RDWR
          when "w"  then IO::WRONLY | IO::TRUNC | IO::CREAT
          when "w+" then IO::RDWR | IO::TRUNC | IO::CREAT
          when "a", "a+" then IO::APPEND | IO::CREAT
          else raise ArgumentError, "unsupported flags: #{flags.inspect}"
          end
        else
          flags.to_i
        end
      end

      def attribute_factory
        V01::Attributes
      end

      def name_factory
        V01::Name
      end
  end

end; end; end; end