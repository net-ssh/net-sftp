require 'net/ssh'
require 'net/sftp/base'
require 'net/sftp/operations/upload'
require 'net/sftp/operations/download'

module Net; module SFTP

  class Session
    include Net::SSH::Loggable

    def self.synchronous(*methods)
      options = methods.last.is_a?(Hash) ? methods.pop : {}
      condition = options[:condition] ? " { #{options[:condition]} }" : ""
      code = ""
      methods.each do |method|
        code << <<-CODE
          def #{method}!(*args, &block)
            object = #{method}(*args, &block)
            loop#{condition}
          end
        CODE
      end
      class_eval(code, __FILE__, __LINE__-6)
    end

    attr_reader :session
    attr_reader :base

    def initialize(session)
      @session    = session
      self.logger = session.logger
      @base       = Net::SFTP::Base.new(session) { yield self if block_given? }
    end

    alias :loop_forever :loop
    def loop(&block)
      base.loop(&block)
    end

    public # SFTP operations
    
      def upload(local, remote, options={}, &block)
        Operations::Upload.new(base, local, remote, options, &block)
      end

      def download(remote, local, options={}, &block)
        Operations::Download.new(base, local, remote, options, &block)
      end

      synchronous :upload, :download, :condition => "object.active?"
  end

end; end