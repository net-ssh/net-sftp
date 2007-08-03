require 'net/ssh'
require 'net/sftp/base'
require 'net/sftp/operations/upload'

module Net; module SFTP

  class Session
    include Net::SSH::Loggable

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

    def upload(local, remote, open_options={}, &block)
      Operations::Upload.new(base, local, remote, open_options, &block)
    end

    def upload!(local, remote, open_options={}, &block)
      upload(local, remote, open_options, &block)
      loop
    end
  end

end; end