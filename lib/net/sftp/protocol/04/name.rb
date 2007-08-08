module Net; module SFTP; module Protocol; module V04

  class Name
    attr_reader :name
    attr_reader :attributes

    def initialize(name, attributes)
      @name, @attributes = name, attributes
    end

    def directory?
      attributes.directory?
    end

    def symlink?
      attributes.symlink?
    end

    def file?
      attributes.file?
    end

    def longname
      @longname ||= begin
        longname = if directory?
          "d"
        elsif symlink?
          "l"
        else
          "-"
        end

        longname << (attributes.permissions & 0400 != 0 ? "r" : "-")
        longname << (attributes.permissions & 0200 != 0 ? "w" : "-")
        longname << (attributes.permissions & 0100 != 0 ? "x" : "-")
        longname << (attributes.permissions & 0040 != 0 ? "r" : "-")
        longname << (attributes.permissions & 0020 != 0 ? "w" : "-")
        longname << (attributes.permissions & 0010 != 0 ? "x" : "-")
        longname << (attributes.permissions & 0004 != 0 ? "r" : "-")
        longname << (attributes.permissions & 0002 != 0 ? "w" : "-")
        longname << (attributes.permissions & 0001 != 0 ? "x" : "-")

        longname << (" %-8s %-8s %8d " % [attributes.owner, attributes.group, attributes.size])

        longname << Time.at(attributes.mtime).strftime("%b %e %H:%M ")
        longname << name
      end
    end
  end

end; end; end; end