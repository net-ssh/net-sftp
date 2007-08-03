module Net; module SFTP

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

  end

end; end
