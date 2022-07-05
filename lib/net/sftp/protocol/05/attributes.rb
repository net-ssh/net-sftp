require 'net/sftp/protocol/01/attributes'

module Net; module SFTP; module Protocol; module V05

  # A class representing the attributes of a file or directory on the server.
  # It may be used to specify new attributes, or to query existing attributes.
  # This particular class is specific to versions 4 and 5 of the SFTP
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
  # * :extended:: a hash of name/value pairs identifying extended info
  #
  # Likewise, when the server sends an Attributes object, all of the
  # above attributes are exposed as methods (though not all will be set with
  # non-nil values from the server).
  class Attributes < V04::Attributes

    F_ATTRIB_BITS       = 0x00000200

    class <<self
      # The list of supported elements in the attributes structure as defined
      # by v5 of the sftp protocol.
      def elements #:nodoc:
        @elements ||= [
          [:type,                :byte,    0],
          [:size,                :int64,   V01::Attributes::F_SIZE],
          [:owner,               :string,  V04::Attributes::F_OWNERGROUP],
          [:group,               :string,  V04::Attributes::F_OWNERGROUP],
          [:permissions,         :long,    V01::Attributes::F_PERMISSIONS],
          [:atime,               :int64,   V04::Attributes::F_ACCESSTIME],
          [:atime_nseconds,      :long,    V04::Attributes::F_ACCESSTIME | V04::Attributes::F_SUBSECOND_TIMES],
          [:createtime,          :int64,   V04::Attributes::F_CREATETIME],
          [:createtime_nseconds, :long,    V04::Attributes::F_CREATETIME | V04::Attributes::F_SUBSECOND_TIMES],
          [:mtime,               :int64,   V04::Attributes::F_MODIFYTIME],
          [:mtime_nseconds,      :long,    V04::Attributes::F_MODIFYTIME | V04::Attributes::F_SUBSECOND_TIMES],
          [:acl,                 :special, V04::Attributes::F_ACL],
          [:attrib_bits,         :long,    F_ATTRIB_BITS],
          [:extended,            :special, V01::Attributes::F_EXTENDED]
        ]
      end
    end

    # The type of the item on the remote server. Must be one of the T_* constants.
    attr_accessor :attrib_bits

  end

end ; end ; end ; end
