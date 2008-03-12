require 'net/sftp/protocol/04/base'

module Net; module SFTP; module Protocol; module V05

  class Base < V04::Base
    include Net::SFTP::Constants

    F_CREATE_NEW         = 0x00000000
    F_CREATE_TRUNCATE    = 0x00000001
    F_OPEN_EXISTING      = 0x00000002
    F_OPEN_OR_CREATE     = 0x00000003
    F_TRUNCATE_EXISTING  = 0x00000004

    F_APPEND_DATA        = 0x00000008
    F_APPEND_DATA_ATOMIC = 0x00000010
    F_TEXT_MODE          = 0x00000020
    F_READ_LOCK          = 0x00000040
    F_WRITE_LOCK         = 0x00000080
    F_DELETE_LOCK        = 0x00000100

    def version
      5
    end

    def rename(name, new_name, flags)
      flags ||= 0
      send_request(FXP_RENAME, :string, name, :string, new_name, :long, flags)
    end

    def open(path, flags, options)
      flags = normalize_open_flags(flags)

      sftp_flags, desired_access = case
        when flags & IO::WRONLY != 0 then
          open = flags & IO::EXCL != 0 ? F_TRUNCATE_EXISTING : F_CREATE_TRUNCATE
          [ open, ACE::F_WRITE_DATA | ACE::F_WRITE_ATTRIBUTES ]
        when flags & IO::RDWR != 0 then
          open = flags & IO::EXCL != 0 ? F_OPEN_EXISTING : F_OPEN_OR_CREATE
          [ open, ACE::F_READ_DATA | ACE::F_READ_ATTRIBUTES | ACE::F_WRITE_DATA | ACE::F_WRITE_ATTRIBUTES ]
        when flags & IO::APPEND != 0 then
          [ F_OPEN_OR_CREATE | F_APPEND_DATA, ACE::F_WRITE_DATA | ACE::F_WRITE_ATTRIBUTES | ACE::F_APPEND_DATA ]
        else
          [ F_OPEN_EXISTING, ACE::F_READ_DATA | ACE::F_READ_ATTRIBUTES ]
      end

      attributes = attribute_factory.new(options)

      send_request(FXP_OPEN, :string, path, :long, desired_access, :long, sftp_flags, :raw, attributes)
    end

  end

end; end; end; end