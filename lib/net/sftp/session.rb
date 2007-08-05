require 'net/ssh'
require 'net/sftp/base'
require 'net/sftp/operations/upload'
require 'net/sftp/operations/upload_tree'

module Net; module SFTP

  class Session
    include Net::SSH::Loggable

    def self.synchronous(*methods)
      code = ""
      methods.each do |method|
        code << <<-CODE
          def #{method}!(*args, &block)
            #{method}(*args, &block)
            loop
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

      def upload_tree(local, remote, options={}, &block)
        Operations::UploadTree.new(base, local, remote, options, &block)
      end

      synchronous :upload, :upload_tree
  end

end; end