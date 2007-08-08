module Net; module SFTP; module Protocol; module V01

  class Name
    attr_reader :name
    attr_reader :longname
    attr_reader :attributes

    def initialize(name, longname, attributes)
      @name, @longname, @attributes = name, longname, attributes
    end

    # These methods are admittedly fragile. It isn't until v4 of the SFTP
    # protocol that a "type" field was included in the attributes, so there
    # is no way to know, without parsing the longname field, what the type
    # of a directory entry is. And the v3 spec explicitly says that clients
    # should not attempt to parse the longname field, since the format is not
    # defined in the spec. We're basing this off of the OpenSSH implementation,
    # which returns output like ls -l. Other SFTP server implementations may
    # not work as successfully.

    def directory?
      longname[0] == ?d
    end

    def symlink?
      longname[0] == ?l
    end

    def file?
      longname[0] == ?-
    end
  end

end; end; end; end