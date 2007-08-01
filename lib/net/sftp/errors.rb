module Net; module SFTP

  # The base exception class for the SFTP system.
  class Exception < RuntimeError; end

  # A exception class for reporting a non-success result of an operation.
  class StatusException < Net::SFTP::Exception

    # The error code (numeric)
    attr_reader :code

    # The description of the error
    attr_reader :description

    # The language in which the description is being reported (usually the
    # empty string)
    attr_reader :language

    # Create a new status exception that reports the given code and
    # description.
    def initialize(code, description, language)
      @code = code
      @description = description
      @language = language
    end

    # Override the default message format, to include the code and
    # description.
    def message
      m = super
      m << " (#{code}, #{description.inspect})"
    end

  end
end; end
