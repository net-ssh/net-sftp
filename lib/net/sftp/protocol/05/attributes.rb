require 'net/sftp/protocol/04/attributes'

module Net; module SFTP; module Protocol; module V05

  # A class representing the attributes of a file or directory on the server.
  # It may be used to specify new attributes, or to query existing attributes.
  # This particular class is specific to version 5 of the SFTP
  # protocol.
  #
  # To specify new attributes, just pass a hash as the argument to the
  # constructor. The following keys are supported:
  #
  # * :type:: the type of the item (integer, one of the T_ constants)
  # * :size:: the size of the item (integer)
  # * :uid:: the user-id that owns the file (integer)
  # * :gid:: the group-id that owns the file (integer)
  # * :owner:: the name of the user that owns the file (string)
  # * :group:: the name of the group that owns the file (string)
  # * :permissions:: the permissions on the file (integer, e.g. 0755)
  # * :atime:: the access time of the file (integer, seconds since epoch)
  # * :atime_nseconds:: the nanosecond component of atime (integer)
  # * :createtime:: the time at which the file was created (integer, seconds since epoch)
  # * :createtime_nseconds:: the nanosecond component of createtime (integer)
  # * :mtime:: the modification time of the file (integer, seconds since epoch)
  # * :mtime_nseconds:: the nanosecond component of mtime (integer)
  # * :acl:: an array of ACL entries for the item
  # * :attrib_bits:: other attributes of the file or directory (as a bit field) (integer)
  # * :extended:: a hash of name/value pairs identifying extended info
  #
  # Likewise, when the server sends an Attributes object, all of the
  # above attributes are exposed as methods (though not all will be set with
  # non-nil values from the server).
  class Attributes < V04::Attributes
    F_BITS              = 0x00000200

    # The list of supported elements in the attributes structure as defined
    # by v5 of the sftp protocol.
    def self.elements #:nodoc:
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
        [:attrib_bits,         :long,    F_BITS],
        [:extended,            :special, F_EXTENDED]
      ]
    end

    # Other attributes of this file or directory (as a bit field)
    attr_accessor :attrib_bits
  end
end ; end ; end ; end