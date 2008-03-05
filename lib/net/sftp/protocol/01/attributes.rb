require 'net/ssh/buffer'

module Net; module SFTP; module Protocol; module V01

  # A class representing the attributes of a file or directory on the server.
  # It may be used to specify new attributes, or to query existing attributes.
  class Attributes

    F_SIZE        = 0x00000001
    F_UIDGID      = 0x00000002
    F_PERMISSIONS = 0x00000004
    F_ACMODTIME   = 0x00000008
    F_EXTENDED    = 0x80000000
    
    class <<self
      def elements
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

      def attr_accessor(name)
        class_eval <<-CODE
          def #{name}
            attributes[:#{name}]
          end

          def #{name}=(value)
            attributes[:#{name}] = value
          end
        CODE
      end

      private

        def parse_extended(buffer)
          extended = Hash.new
          buffer.read_long.times do
            extended[buffer.read_string] = buffer.read_string
          end
          extended
        end
    end

    attr_reader   :attributes

    attr_accessor :size
    attr_writer   :uid
    attr_writer   :gid
    attr_accessor :permissions
    attr_accessor :atime
    attr_accessor :mtime
    attr_accessor :extended

    # Create a new Attributes with the given attributes.
    def initialize(attributes={})
      @attributes = attributes
    end

    def uid
      if attributes[:owner] && !attributes.key?(:uid)
        require 'etc'
        attributes[:uid] = Etc.getpwnam(hash[:owner]).uid
      end
      attributes[:uid]
    end

    def gid
      if attributes[:group] && !attributes.key?(:gid)
        require 'etc'
        attributes[:gid] = Etc.getgrnam(attributes[:group]).gid
      end
      attributes[:gid]
    end

    # Convert the object to a string suitable for passing in an SFTP
    # packet.
    def to_s
      flags = 0

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

      def encode_extended(buffer)
        buffer.write_long extended.size
        extended.each { |k,v| buffer.write_string k, v }
      end

  end

end ; end ; end ; end
