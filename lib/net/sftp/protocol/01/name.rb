module Net; module SFTP; module Protocol; module V01

  # Represents a single named item on the remote server. This includes the
  # name, attributes about the item, and the "longname", which is intended
  # for use when displaying directory data, and has no specified format.
  #
  # This class also provides means to determine the type of the named item.
  # However, these methods are admittedly fragile. It isn't until v4 of the
  # SFTP protocol that a "type" field was included in the attributes, so there
  # is no way to know, without parsing the longname field, what the type
  # of a directory entry is. And the v3 spec explicitly says that clients
  # should not attempt to parse the longname field, since the format is not
  # defined in the spec. We're basing this off of the OpenSSH implementation,
  # which returns output like ls -l. Other SFTP server implementations may
  # not work as successfully.
  class Name
    # The name of the item on the remote server.
    attr_reader :name

    # The display-ready name of the item, possibly with other attributes.
    attr_reader :longname

    # The Attributes object describing this item.
    attr_reader :attributes

    # Create a new Name object with the given name, longname, and attributes.
    def initialize(name, longname, attributes)
      @name, @longname, @attributes = name, longname, attributes
    end

    # Returns +true+ if the item appears to be a directory. It does this by
    # examining the first byte of the #longname field, a practice that the
    # SFTP protocol specifically forbids, since the format of the #longname
    # field is unspecified. However, there is no other way given to determine
    # the type of a name entry.
    def directory?
      longname[0] == ?d
    end

    # Returns +true+ if the item appears to be a symlink. It does this by
    # examining the first byte of the #longname field, a practice that the
    # SFTP protocol specifically forbids, since the format of the #longname
    # field is unspecified. However, there is no other way given to determine
    # the type of a name entry.
    def symlink?
      longname[0] == ?l
    end

    # Returns +true+ if the item appears to be a regular file. It does this by
    # examining the first byte of the #longname field, a practice that the
    # SFTP protocol specifically forbids, since the format of the #longname
    # field is unspecified. However, there is no other way given to determine
    # the type of a name entry.
    def file?
      longname[0] == ?-
    end
  end

end; end; end; end