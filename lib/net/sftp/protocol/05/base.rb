require 'net/sftp/protocol/04/base'

module Net; module SFTP; module Protocol; module V05

  class Base < V04::Base
    def version
      5
    end

    def rename(name, new_name, flags=nil)
      send_request(FXP_RENAME, :string, name, :string, new_name, :long, flags || 0)
    end

    def open(path, flags, options)
      flags = normalize_open_flags(flags)

      sftp_flags, desired_access = if flags & (IO::WRONLY | IO::RDWR) != 0
          open = if flags & (IO::CREAT | IO::EXCL) == (IO::CREAT | IO::EXCL)
            FV5::CREATE_NEW
          elsif flags & (IO::CREAT | IO::TRUNC) == (IO::CREAT | IO::TRUNC)
            FV5::CREATE_TRUNCATE
          elsif flags & IO::CREAT == IO::CREAT
            FV5::OPEN_OR_CREATE
          else
            FV5::OPEN_EXISTING
          end
          access = ACE::Mask::WRITE_DATA | ACE::Mask::WRITE_ATTRIBUTES
          access |= ACE::Mask::READ_DATA | ACE::Mask::READ_ATTRIBUTES if (flags & IO::RDWR) == IO::RDWR
          if flags & IO::APPEND == IO::APPEND
            open |= FV5::APPEND_DATA
            access |= ACE::Mask::APPEND_DATA
          end
          [open, access]
        else
          [FV5::OPEN_EXISTING, ACE::Mask::READ_DATA | ACE::Mask::READ_ATTRIBUTES]
        end

      attributes = attribute_factory.new(options)

      send_request(FXP_OPEN, :string, path, :long, desired_access, :long, sftp_flags, :raw, attributes.to_s)
    end

  end

end; end; end; end