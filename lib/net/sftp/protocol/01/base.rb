require 'net/ssh/loggable'
require 'net/sftp/constants'
require 'net/sftp/packet'
require 'net/sftp/protocol/base'
require 'net/sftp/protocol/01/attributes'

module Net; module SFTP; module Protocol; module V01

  class Base < Protocol::Base
    F_READ   = 0x00000001
    F_WRITE  = 0x00000002
    F_APPEND = 0x00000004
    F_CREAT  = 0x00000008
    F_TRUNC  = 0x00000010
    F_EXCL   = 0x00000020

    def create_attributes(options={})
      V01::Attributes.new(options)
    end

    def parse_handle_packet(packet)
      packet.read_string
    end

    def parse_status_packet(packet)
      packet.read_long
    end

    def parse_data_packet(packet)
      packet.read_string
    end

    def open(path, flags, mode=0600)
      if String === flags
        case flags.tr("b", "")
        when "r"  then flags = IO::RDONLY
        when "r+" then flags = IO::RDWR
        when "w"  then flags = IO::WRONLY | IO::TRUNC | IO::CREAT
        when "w+" then flags = IO::RDWR | IO::TRUNC | IO::CREAT
        when "a", "a+" then flags = IO::APPEND | IO::CREAT
        else raise ArgumentError, "unsupported flags: #{flags.inspect}"
        end
      end

      if    flags & IO::WRONLY != 0 then sftp_flags = F_WRITE
      elsif flags & IO::RDWR   != 0 then sftp_flags = F_READ | F_WRITE
      elsif flags & IO::APPEND != 0 then sftp_flags = F_APPEND
      else  sftp_flags = F_READ
      end

      sftp_flags |= F_CREAT if flags & IO::CREAT != 0
      sftp_flags |= F_TRUNC if flags & IO::TRUNC != 0
      sftp_flags |= F_EXCL  if flags & IO::EXCL  != 0

      attributes = create_attributes(:permissions => mode)

      send_request(FXP_OPEN, :string, path, :long, sftp_flags, :raw, attributes)
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
  end

end; end; end; end