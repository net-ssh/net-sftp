require 'net/ssh'
require 'net/sftp/constants'
require 'net/sftp/errors'
require 'net/sftp/packet'
require 'net/sftp/protocol'
require 'net/sftp/request'
require 'net/sftp/response'

module Net; module SFTP

  class Session
    include Net::SSH::Loggable
    include Net::SFTP::Constants

    HIGHEST_PROTOCOL_VERSION_SUPPORTED = 6

    attr_reader :session
    attr_reader :channel
    attr_reader :state
    attr_reader :input
    attr_reader :protocol
    attr_reader :pending_requests

    def initialize(session, &block)
      @session = session
      @input   = Net::SSH::Buffer.new
      self.logger = session.logger
      @state = :closed
      connect!(&block)
    end

    def close_channel
      channel.close
    end

    def connect!(&block)
      return unless state == :closed
      @state = :opening
      @channel = session.open_channel(&method(:when_channel_confirmed))
      @packet_length = nil
      @protocol = nil
      @on_ready = block
    end

    alias :loop_forever :loop
    def loop(&block)
      block ||= Proc.new { pending_requests.any? }
      session.loop(&block)
    end

    def send_packet(type, *args)
      data = Net::SSH::Buffer.from(*args)
      msg = Net::SSH::Buffer.from(:long, data.length+1, :byte, type, :raw, data)
      channel.send_data(msg.to_s)
    end

    public

      def open(path, flags="r", options={}, &callback)
        request :open, path, flags, options, &callback
      end

      def close(handle, &callback)
        request :close, handle, &callback
      end

      def read(handle, offset, length, &callback)
        request :read, handle, offset, length, &callback
      end

      def write(handle, offset, data, &callback)
        request :write, handle, offset, data, &callback
      end

      def lstat(path, flags=nil, &callback)
        request :lstat, path, flags, &callback
      end

      def fstat(handle, flags=nil, &callback)
        request :fstat, handle, flags, &callback
      end

      def setstat(path, attrs, &callback)
        request :setstat, path, attrs, &callback
      end

      def fsetstat(handle, attrs, &callback)
        request :fsetstat, handle, attrs, &callback
      end

      def opendir(path, &callback)
        request :opendir, path, &callback
      end

      def readdir(handle, &callback)
        request :readdir, handle, &callback
      end

      def remove(filename, &callback)
        request :remove, filename, &callback
      end

      def mkdir(path, attrs={}, &callback)
        request :mkdir, path, attrs, &callback
      end

      def rmdir(path, &callback)
        request :rmdir, path, &callback
      end

      def realpath(path, &callback)
        request :realpath, path, &callback
      end

      def stat(path, flags=nil, &callback)
        request :stat, path, flags, &callback
      end

      def rename(name, new_name, flags=nil, &callback)
        request :rename, name, new_name, flags, &callback
      end

      def readlink(path, &callback)
        request :readlink, path, &callback
      end

      def symlink(path, target, &callback)
        request :symlink, path, target, &callback
      end

      def link(new_link_path, existing_path, symlink=true, &callback)
        request :link, new_link_path, existing_path, symlink, &callback
      end

    private

      def request(type, *args, &callback)
        request = Request.new(self, type, protocol.send(type, *args), &callback)
        pending_requests[request.id] = request
      end

      def when_channel_confirmed(channel)
        debug { "requesting sftp subsystem" }
        @state = :subsystem
        channel.subsystem("sftp", &method(:when_subsystem_started))
      end

      def when_subsystem_started(channel, success)
        raise Net::SFTP::Exception, "could not start SFTP subsystem" unless success

        trace { "sftp subsystem successfully started" }
        @state = :init

        channel.on_data { |c,data| input.append(data) }
        channel.on_extended_data { |c,t,data| debug { data } }

        channel.on_close(&method(:when_channel_closed))
        channel.on_process(&method(:when_channel_polled))

        send_packet(FXP_INIT, :long, HIGHEST_PROTOCOL_VERSION_SUPPORTED)
      end

      def when_channel_closed(channel)
        trace { "sftp channel closed" }
        @channel = nil
        @state = :closed
      end

      def when_channel_polled(channel)
        while input.length > 0
          if @packet_length.nil?
            # make sure we've read enough data to tell how long the packet is
            return unless input.length >= 4
            @packet_length = input.read_long
          end

          return unless input.length >= @packet_length
          packet = Net::SFTP::Packet.new(input.read(@packet_length))
          input.consume!
          @packet_length = nil

          trace { "received sftp packet #{packet.type} len #{packet.length}" }

          if packet.type == FXP_VERSION
            do_version(packet)
          else
            dispatch_request(packet)
          end
        end
      end

      def do_version(packet)
        trace { "negotiating sftp protocol version, mine is #{HIGHEST_PROTOCOL_VERSION_SUPPORTED}" }

        server_version = packet.read_long
        trace { "server reports sftp version #{server_version}" }

        negotiated_version = [server_version, HIGHEST_PROTOCOL_VERSION_SUPPORTED].min
        debug { "negotiated version is #{negotiated_version}" }

        extensions = {}
        until packet.eof?
          name = packet.read_string
          data = packet.read_string
          extensions[name] = data
        end

        @protocol = Protocol.load(self, negotiated_version)
        @pending_requests = {}

        @state = :open
        @on_ready.call(self) if @on_ready
      end

      def dispatch_request(packet)
        id = packet.read_long
        request = pending_requests.delete(id) or raise Net::SFTP::Exception, "no such request `#{id}'"
        request.respond_to(packet)
      end
  end

end; end