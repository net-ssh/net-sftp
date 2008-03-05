require 'net/sftp/protocol/01/attributes'

module Net; module SFTP; module Protocol; module V04

  # Version 4 of the SFTP protocol made some pretty significant alterations to
  # the File Attributes data type. This encapsulates those changes.
   class Attributes < V01::Attributes

    F_ACCESSTIME        = 0x00000008
    F_CREATETIME        = 0x00000010
    F_MODIFYTIME        = 0x00000020
    F_ACL               = 0x00000040
    F_OWNERGROUP        = 0x00000080
    F_SUBSECOND_TIMES   = 0x00000100
    
    attr_accessor :type
    attr_writer   :owner
    attr_writer   :group
    attr_accessor :atime_nseconds
    attr_accessor :createtime
    attr_accessor :createtime_nseconds
    attr_accessor :mtime
    attr_accessor :acl

    ACL = Struct.new(:type, :flag, :mask, :who)

    def self.elements
      @elements ||= [
        [:type,                :byte,    0],
        [:size,                :int64,   F_SIZE],
        [:owner,               :string,  F_OWNERGROUP],
        [:group,               :string,  F_OWNERGROUP],
        [:permissions,         :long,    F_PERMISSIONS],
        [:atime,               :int64,   F_ACCESSTIME],
        [:atime_nseconds,      :long,    F_ACCESSTIME | F_SUBSECOND_TIMES],
        [:createtime,          :int64,   F_CREATETIME],
        [:createtime_nseconds, :long,    F_CREATETIME | F_SUBSECOND_TIMES],
        [:mtime,               :int64,   F_MODIFYTIME],
        [:mtime_nseconds,      :long,    F_MODIFYTIME | F_SUBSECOND_TIMES],
        [:acl,                 :special, F_ACL],
        [:extended,            :special, F_EXTENDED]
      ]
    end

    def self.parse_acl(buffer)
      acl_buf = Net::SSH::Buffer.new(buffer.read_string)
      acl = []
      acl_buf.read_long.times do
        acl << ACL.new(acl_buf.read_long, acl_buf.read_long, acl_buf.read_long, acl_buf.read_string)
      end
      acl
    end
    private_class_method :parse_acl

    T_REGULAR      = 1
    T_DIRECTORY    = 2
    T_SYMLINK      = 3
    T_SPECIAL      = 4
    T_UNKNOWN      = 5
    T_SOCKET       = 6
    T_CHAR_DEVICE  = 7
    T_BLOCK_DEVICE = 8
    T_FIFO         = 9

    def initialize(attributes={})
      super
      attributes[:type] ||= T_REGULAR
    end

    def directory?
      type == T_DIRECTORY
    end

    def symlink?
      type == T_SYMLINK
    end

    def file?
      type == T_REGULAR
    end

    def owner
      if attributes[:uid] && !attributes.key?(:owner)
        require 'etc'
        attributes[:owner] = Etc.getpwuid(hash[:uid]).name
      end
      attributes[:owner]
    end

    def group
      if attributes[:gid] && !attributes.key?(:group)
        require 'etc'
        attributes[:group] = Etc.getgrgid(attributes[:gid]).name
      end
      attributes[:group]
    end

    private

      def encode_acl(buffer)
        acl_buf = Net::SSH::Buffer.from(:long, acl.length)
        acl.each do |item|
          acl_buf.write_long item.type, item.flag, item.mask
          acl_buf.write_string item.who
        end
        buffer.write_string(acl_buf.to_s)
      end

  end

end ; end ; end ; end
