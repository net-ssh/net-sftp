module Net; module SFTP

  class Response
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

    attr_reader :request
    attr_reader :data
    attr_reader :code
    attr_reader :message

    def initialize(request, data={})
      @request, @data = request, data
      @code, @message = data[:code] || FX_OK, data[:message]
    end

    def [](key)
      data[key.to_sym]
    end

    def to_s
      if message && !message.empty? && message.downcase != MAP[code]
        "#{message} (#{MAP[code]}, #{code})"
      else
        "#{MAP[code]} (#{code})"
      end
    end

    alias :to_str :to_s

    def ok?
      code == FX_OK
    end

    def eof?
      code == FX_EOF
    end

    MAP = constants.inject({}) do |memo, name|
      next memo unless name =~ /^FX_(.*)/
      memo[const_get(name)] = $1.downcase.tr("_", " ")
      memo
    end
  end

end; end