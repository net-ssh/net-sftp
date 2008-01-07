module Net; module SFTP

  # The base exception class for the SFTP system.
  class Exception < RuntimeError; end

  # A exception class for reporting a non-success result of an operation.
  class StatusException < Net::SFTP::Exception

    # The response object that caused the exception.
    attr_reader :response

    # The error code (numeric)
    attr_reader :code

    # The description of the error
    attr_reader :description

    # Create a new status exception that reports the given code and
    # description.
    def initialize(response)
      @response = response
      @code = response.code
      @description = response.message
      @description = Response::MAP[@code] if @description.nil? || @description.empty?
    end

    # Override the default message format, to include the code and
    # description.
    def message
      m = super
      m << " (#{code}, #{description.inspect})"
    end

  end
end; end
