require 'net/ssh/loggable'
require 'net/sftp/operations/file'

module Net; module SFTP; module Operations

  class FileFactory
    attr_reader :sftp

    def initialize(sftp)
      @sftp = sftp
    end

    def open(name, flags="r", mode=nil, &block)
      handle = sftp.open!(name, flags, :permissions => mode)
      file = Operations::File.new(sftp, handle)

      if block_given?
        begin
          yield file
        ensure
          file.close
        end
      else
        return file
      end
    end
  end

end; end; end
