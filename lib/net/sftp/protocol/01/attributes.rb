require 'net/ssh/buffer'

module Net; module SFTP; module Protocol; module V01

  # A class representing the attributes of a file or directory on the server.
  # It may be used to specify new attributes, or to query existing attributes.
  #
  # To specify new attributes, just pass a hash as the argument to the
  # constructor. The following keys are supported:
  #
  # * :size:: the size of the file
  # * :uid:: the user-id that owns the file (integer)
  # * :gid:: the group-id that owns the file (integer)
  # * :owner:: the name of the user that owns the file (string)
  # * :group:: the name of the group that owns the file (string)
  # * :permissions:: the permissions on the file (integer, e.g. 0755)
  # * :atime:: the access time of the file (integer, seconds since epoch)
  # * :mtime:: the modification time of the file (integer, seconds since epoch)
  # * :extended:: a hash of name/value pairs identifying extended info
  #
  # Likewise, when the server sends an Attributes object, all of the
  # above attributes are exposed as methods (though not all will be set with
  # non-nil values from the server).
  class Attributes

    F_SIZE        = 0x00000001
    F_UIDGID      = 0x00000002
    F_PERMISSIONS = 0x00000004
    F_ACMODTIME   = 0x00000008
    F_EXTENDED    = 0x80000000
    
    class <<self
      # Returns the array of attribute meta-data that defines the structure of
      # the attributes packet as described by this version of the protocol.
      def elements #:nodoc:
        @elements ||= [
          [:size,                :int64,   F_SIZE],
          [:uid,                 :long,    F_UIDGID],
          [:gid,                 :long,    F_UIDGID],
          [:permissions,         :long,    F_PERMISSIONS],
          [:atime,               :long,    F_ACMODTIME],
          [:mtime,               :long,    F_ACMODTIME],
          [:extended,            :special, F_EXTENDED]
        ]
      end

      # Parses the given buffer and returns an Attributes object compsed from
      # the data extracted from it.
      def from_buffer(buffer)
        flags = buffer.read_long
        data = {}

        elements.each do |name, type, condition|
          if flags & condition == condition
            if type == :special
              data[name] = send("parse_#{name}", buffer)
            else
              data[name] = buffer.send("read_#{type}")
            end
          end
        end

        new(data)
      end

      # A convenience method for defining methods that expose specific
      # attributes.
      def attr_accessor(name, options={}) #:nodoc:
        unless options[:write_only]
          method = <<-CODE
            def #{name}
              attributes[:#{name}]
            end
          CODE
        end

        class_eval <<-CODE
          #{method}

          def #{name}=(value)
            attributes[:#{name}] = value
          end
        CODE
      end

      private

        # Parse the hash of extended data from the buffer.
        def parse_extended(buffer)
          extended = Hash.new
          buffer.read_long.times do
            extended[buffer.read_string] = buffer.read_string
          end
          extended
        end
    end

    # The hash of name/value pairs that backs this Attributes instance
    attr_reader   :attributes

    # The size of the file.
    attr_accessor :size

    # The user-id of the user that owns the file
    attr_accessor :uid, :write_only => true

    # The group-id of the user that owns the file
    attr_accessor :gid, :write_only => true

    # The permissions on the file
    attr_accessor :permissions

    # The last access time of the file
    attr_accessor :atime

    # The modification time of the file
    attr_accessor :mtime

    # The hash of name/value pairs identifying extended information about the file
    attr_accessor :extended

    # Create a new Attributes instance with the given attributes. The
    # following keys are supported:
    #
    # * :size:: the size of the file
    # * :uid:: the user-id that owns the file (integer)
    # * :gid:: the group-id that owns the file (integer)
    # * :owner:: the name of the user that owns the file (string)
    # * :group:: the name of the group that owns the file (string)
    # * :permissions:: the permissions on the file (integer, e.g. 0755)
    # * :atime:: the access time of the file (integer, seconds since epoch)
    # * :mtime:: the modification time of the file (integer, seconds since epoch)
    # * :extended:: a hash of name/value pairs identifying extended info
    def initialize(attributes={})
      @attributes = attributes
    end

    # Returns the user-id of the user that owns the file, or +nil+ if that
    # information is not available. If an :owner key exists, but not a :uid
    # key, the Etc module will be used to reverse lookup the id from the name.
    # This might fail on some systems (e.g., Windows).
    def uid
      if attributes[:owner] && !attributes.key?(:uid)
        require 'etc'
        attributes[:uid] = Etc.getpwnam(attributes[:owner]).uid
      end
      attributes[:uid]
    end

    # Returns the group-id of the group that owns the file, or +nil+ if that
    # information is not available. If a :group key exists, but not a :gid
    # key, the Etc module will be used to reverse lookup the id from the name.
    # This might fail on some systems (e.g., Windows).
    def gid
      if attributes[:group] && !attributes.key?(:gid)
        require 'etc'
        attributes[:gid] = Etc.getgrnam(attributes[:group]).gid
      end
      attributes[:gid]
    end

    # Returns the username of the user that owns the file, or +nil+ if that
    # information is not available. If the :uid is given, but not the :owner,
    # the Etc module will be used to lookup the name from the id. This might
    # fail on some systems (e.g. Windows).
    def owner
      if attributes[:uid] && !attributes[:owner]
        require 'etc'
        attributes[:owner] = Etc.getpwuid(attributes[:uid].to_i).name
      end
      attributes[:owner]
    end

    # Returns the group name of the group that owns the file, or +nil+ if that
    # information is not available. If the :gid is given, but not the :group,
    # the Etc module will be used to lookup the name from the id. This might
    # fail on some systems (e.g. Windows).
    def group
      if attributes[:gid] && !attributes[:group]
        require 'etc'
        attributes[:group] = Etc.getgrgid(attributes[:gid].to_i).name
      end
      attributes[:group]
    end

    # Convert the object to a string suitable for passing in an SFTP
    # packet. This is the raw representation of the attribute packet payload,
    # and is not intended to be human readable.
    def to_s
      flags = 0

      # force the uid/gid to be translated from owner/group, if those keys
      # were given on instantiation
      uid; gid

      self.class.elements.each do |name, type, condition|
        flags |= condition if attributes[name]
      end

      buffer = Net::SSH::Buffer.from(:long, flags)
      self.class.elements.each do |name, type, condition|
        if flags & condition == condition
          if type == :special
            send("encode_#{name}", buffer)
          else
            buffer.send("write_#{type}", attributes[name])
          end
        end
      end

      buffer.to_s
    end

    private

      # Encodes information about the extended info onto the end of the given
      # buffer.
      def encode_extended(buffer)
        buffer.write_long extended.size
        extended.each { |k,v| buffer.write_string k, v }
      end

  end

end ; end ; end ; end
