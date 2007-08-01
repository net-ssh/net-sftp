module Net; module SFTP

  class Response
    def self.ok(id)
      new(id, FX_OK, "Success")
    end

    attr_reader :id
    attr_reader :code
    attr_reader :message
    attr_reader :language

    def initialize(id, code, message=nil, language=nil)
      @id = id
      @code, @message, @language = code, message, language
    end

    def to_s
      if message && !message.empty? && message.downcase != MAP[code]
        "#{message} (#{MAP[code]} #{code})"
      else
        "#{MAP[code]} #{code}"
      end
    end

    def ok?
      code == FX_OK
    end

    FX_OK                     = 0
    FX_EOF                    = 1
    FX_NO_SUCH_FILE           = 2
    FX_PERMISSION_DENIED      = 3
    FX_FAILURE                = 4
    FX_BAD_MESSAGE            = 5
    FX_NO_CONNECTION          = 6
    FX_CONNECTION_LOST        = 7
    FX_OP_UNSUPPORTED         = 8
    FX_INVALID_HANDLE         = 9
    FX_NO_SUCH_PATH           = 10
    FX_FILE_ALREADY_EXISTS    = 11
    FX_WRITE_PROTECT          = 12
    FX_NO_MEDIA               = 13
    FX_NO_SPACE_ON_FILESYSTEM = 14
    FX_QUOTA_EXCEEDED         = 15
    FX_UNKNOWN_PRINCIPLE      = 16
    FX_LOCK_CONFlICT          = 17
    FX_DIR_NOT_EMPTY          = 18
    FX_NOT_A_DIRECTORY        = 19
    FX_INVALID_FILENAME       = 20
    FX_LINK_LOOP              = 21

    MAP = Constants.constants.inject({}) do |memo, name|
      next unless name =~ /^FX_(.*)/
      memo[const_get(name)] = $1.downcase.tr("_", " ")
      memo
    end
  end

end; end