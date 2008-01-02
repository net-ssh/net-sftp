require 'net/ssh'
require 'net/sftp/base'
require 'net/sftp/operations/upload'
require 'net/sftp/operations/download'
require 'net/sftp/operations/file_factory'

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

    def open
      loop { base.opening? }
      yield self if block_given?
    end

    public # SFTP operations
    
      def upload(local, remote, options={}, &block)
        Operations::Upload.new(base, local, remote, options, &block)
      end

      def download(remote, local, options={}, &block)
        Operations::Download.new(base, local, remote, options, &block)
      end

      synchronous :upload, :download, :condition => "object.active?"

      def mkdir(remote, options={})
        base.mkdir(remote, options) do |status|
          raise "mkdir #{remote}: #{status}" unless status.ok?
          yield if block_given?
        end
      end

      def rmdir(remote)
        base.rmdir(remote) do |status|
          raise "rmdir #{remote}: #{status}" unless status.ok?
          yield if block_given?
        end
      end

      synchronous :mkdir, :rmdir, :condition => "object.pending?"

      def file
        @file ||= Operations::FileFactory.new(base)
      end
  end

end; end