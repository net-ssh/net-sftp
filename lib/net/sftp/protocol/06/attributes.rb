require 'net/sftp/protocol/04/attributes'

module Net; module SFTP; module Protocol; module V06

  class Attributes < V04::Attributes
    F_BITS              = 0x00000200
    F_ALLOCATION_SIZE   = 0x00000400
    F_TEXT_HINT         = 0x00000800
    F_MIME_TYPE         = 0x00001000
    F_LINK_COUNT        = 0x00002000
    F_UNTRANSLATED_NAME = 0x00004000
    F_CTIME             = 0x00008000

    def self.elements
      @elements ||= [
        [:type,                :byte,    0],
        [:size,                :int64,   F_SIZE],
        [:allocation_size,     :int64,   F_ALLOCATION_SIZE],
        [:owner,               :string,  F_OWNERGROUP],
        [:group,               :string,  F_OWNERGROUP],
        [:permissions,         :long,    F_PERMISSIONS],
        [:atime,               :int64,   F_ACCESSTIME],
        [:atime_nseconds,      :long,    F_ACCESSTIME | F_SUBSECOND_TIMES],
        [:createtime,          :int64,   F_CREATETIME],
        [:createtime_nseconds, :long,    F_CREATETIME | F_SUBSECOND_TIMES],
        [:mtime,               :int64,   F_MODIFYTIME],
        [:mtime_nseconds,      :long,    F_MODIFYTIME | F_SUBSECOND_TIMES],
        [:ctime,               :int64,   F_CTIME],
        [:ctime_nseconds,      :long,    F_CTIME | F_SUBSECOND_TIMES],
        [:acl,                 :special, F_ACL],
        [:attrib_bits,         :long,    F_BITS],
        [:attrib_bits_valid,   :long,    F_BITS],
        [:text_hint,           :byte,    F_TEXT_HINT],
        [:mime_type,           :string,  F_MIME_TYPE],
        [:link_count,          :long,    F_LINK_COUNT],
        [:untranslated_name,   :string,  F_UNTRANSLATED_NAME],
        [:extended,            :special, F_EXTENDED]
      ]
    end

    attr_accessor :allocation_size
    attr_accessor :ctime
    attr_accessor :ctime_nseconds
    attr_accessor :attrib_bits
    attr_accessor :attrib_bits_valid
    attr_accessor :text_hint
    attr_accessor :mime_type
    attr_accessor :link_count
    attr_accessor :untranslated_name
  end

end; end; end; end