module Net module SFTP

  # The packet types and other general constants used by the SFTP protocol.
  # See the specification for the SFTP protocol for a full discussion of their
  # meaning and usage.
  module Constants

    FXP_INIT             = 1
    FXP_VERSION          = 2

    FXP_OPEN             = 3
    FXP_CLOSE            = 4
    FXP_READ             = 5
    FXP_WRITE            = 6
    FXP_LSTAT            = 7
    FXP_FSTAT            = 8
    FXP_SETSTAT          = 9
    FXP_FSETSTAT         = 10
    FXP_OPENDIR          = 11
    FXP_READDIR          = 12
    FXP_REMOVE           = 13
    FXP_MKDIR            = 14
    FXP_RMDIR            = 15
    FXP_REALPATH         = 16
    FXP_STAT             = 17
    FXP_RENAME           = 18
    FXP_READLINK         = 19
    FXP_SYMLINK          = 20
    FXP_LINK             = 21
    FXP_BLOCK            = 22
    FXP_UNBLOCK          = 23

    FXP_STATUS           = 101
    FXP_HANDLE           = 102
    FXP_DATA             = 103
    FXP_NAME             = 104
    FXP_ATTRS            = 105

    FXP_EXTENDED         = 106
    FXP_EXTENDED_REPLY   = 107

    FXP_RENAME_OVERWRITE = 0x00000001
    FXP_RENAME_ATOMIC    = 0x00000002
    FXP_RENAME_NATIVE    = 0x00000004

    ACE4_ACCESS_ALLOWED_ACE_TYPE      = 0x00000000
    ACE4_ACCESS_DENIED_ACE_TYPE       = 0x00000001
    ACE4_SYSTEM_AUDIT_ACE_TYPE        = 0x00000002
    ACE4_SYSTEM_ALARM_ACE_TYPE        = 0x00000003

    ACE4_FILE_INHERIT_ACE             = 0x00000001
    ACE4_DIRECTORY_INHERIT_ACE        = 0x00000002
    ACE4_NO_PROPAGATE_INHERIT_ACE     = 0x00000004
    ACE4_INHERIT_ONLY_ACE             = 0x00000008
    ACE4_SUCCESSFUL_ACCESS_ACE_FLAG   = 0x00000010
    ACE4_FAILED_ACCESS_ACE_FLAG       = 0x00000020
    ACE4_IDENTIFIER_GROUP             = 0x00000040

    ACE4_READ_DATA                    = 0x00000001
    ACE4_LIST_DIRECTORY               = 0x00000001
    ACE4_WRITE_DATA                   = 0x00000002
    ACE4_ADD_FILE                     = 0x00000002
    ACE4_APPEND_DATA                  = 0x00000004
    ACE4_ADD_SUBDIRECTORY             = 0x00000004
    ACE4_READ_NAMED_ATTRS             = 0x00000008
    ACE4_WRITE_NAMED_ATTRS            = 0x00000010
    ACE4_EXECUTE                      = 0x00000020
    ACE4_DELETE_CHILD                 = 0x00000040
    ACE4_READ_ATTRIBUTES              = 0x00000080
    ACE4_WRITE_ATTRIBUTES             = 0x00000100
    ACE4_DELETE                       = 0x00010000
    ACE4_READ_ACL                     = 0x00020000
    ACE4_WRITE_ACL                    = 0x00040000
    ACE4_WRITE_OWNER                  = 0x00080000
    ACE4_SYNCHRONIZE                  = 0x00100000

  end

end end
