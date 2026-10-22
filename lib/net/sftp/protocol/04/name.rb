module Net; module SFTP; module Protocol; module V04

  # Represents a single named item on the remote server. This includes the
  # name, and attributes about the item, and the "longname".
  #
  # For backwards compatibility with the format and interface of the Name
  # structure from previous protocol versions, this also exposes a #longname
  # method, which returns a string that can be used to display this item in
  # a directory listing.
  class Name
    # The name of the item on the remote server.
    attr_accessor :name

    # Attributes instance describing this item.
    attr_reader :attributes

    # Create a new Name object with the given name and attributes.
    def initialize(name, attributes)
      @name, @attributes = name, attributes
    end

    # Returns +true+ if the item is a directory.
    def directory?
      attributes.directory?
    end

    # Returns +true+ if the item is a symlink.
    def symlink?
      attributes.symlink?
    end

    # Returns +true+ if the item is a regular file.
    def file?
      attributes.file?
    end

    # Returns a string representing this file, in a format similar to that
    # used by the unix "ls" utility.
    def longname
      @longname ||= begin
        longname = if directory?
          "d"
        elsif symlink?
          "l"
        else
          "-"
        end.dup

        # Fields the server omitted are shown as "?", like GNU ls -l does for entries it cannot stat.
        if (permissions = attributes.permissions)
          longname << (permissions & 0400 != 0 ? "r" : "-")
          longname << (permissions & 0200 != 0 ? "w" : "-")
          longname << (permissions & 0100 != 0 ? "x" : "-")
          longname << (permissions & 0040 != 0 ? "r" : "-")
          longname << (permissions & 0020 != 0 ? "w" : "-")
          longname << (permissions & 0010 != 0 ? "x" : "-")
          longname << (permissions & 0004 != 0 ? "r" : "-")
          longname << (permissions & 0002 != 0 ? "w" : "-")
          longname << (permissions & 0001 != 0 ? "x" : "-")
        else
          longname << "?" * 9
        end

        longname << (" %-8s %-8s %8s " % [attributes.owner || "?", attributes.group || "?", attributes.size || "?"])

        longname << if attributes.mtime
          Time.at(attributes.mtime).strftime("%b %e %H:%M ")
        else
          "%12s " % "?"
        end
        longname << name
      end
    end
  end

end; end; end; end
