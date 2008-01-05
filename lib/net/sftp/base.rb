require 'net/ssh'
require 'net/sftp/constants'
require 'net/sftp/errors'
require 'net/sftp/packet'
require 'net/sftp/protocol'
require 'net/sftp/request'
require 'net/sftp/response'

module Net; module SFTP

  # Presents the low-level SFTP operations in a protocol-agnostic way. Requests
  # get routed to the appropriate Protocol instance. Generally, you'll want to
  # use the Session class instead of this one, but you can get at the underlying
  # Base instance anytime you want, e.g.:
  #
  #   request = session.base.remove("/path/to/file")
  #   request.wait
  #
  # Theoretically, you could instantiate this class directly, but it is
  # easier just to go through the Session class.
  class Base
    include Net::SSH::Loggable
    include Net::SFTP::Constants

    # The highest protocol version supported by the Net::SFTP library.
    HIGHEST_PROTOCOL_VERSION_SUPPORTED = 6

    # A reference to the Net::SSH session object that powers this SFTP session.
    attr_reader :session

    # The Net::SSH::Connection::Channel object that the SFTP session is being
    # processed by.
    attr_reader :channel

    # The state of the SFTP connection. It will be :opening, :subsystem, :init,
    # :open, or :closed.
    attr_reader :state

    # The protocol instance being used by this SFTP session. Useful for
    # querying the protocol version in effect.
    attr_reader :protocol

    # The hash of pending requests. Any requests that have been sent and which
    # the server has not yet responded to will be represented here.
    attr_reader :pending_requests

    # Creates a new Net::SFTP instance atop the given Net::SSH connection.
    # This will return immediately, before the SFTP connection has been properly
    # initialized. Once the connection is ready, the given block will be called.
    # If you want to block until the connection has been initialized, try this:
    #
    #   base = Net::SFTP::Base.new(ssh)
    #   base.loop { base.opening? }
    def initialize(session, &block)
      @session    = session
      @input      = Net::SSH::Buffer.new
      self.logger = session.logger
      @state      = :closed

      connect(&block)
    end

    # Closes the SFTP connection, but not the SSH connection. Blocks until the
    # session has terminated. Once the session has terminated, further operations
    # on this object will result in errors. You can reopen the SFTP session
    # via the #connect method.
    def close_channel
      return unless open?
      channel.close
      loop { !closed? }
    end

    # Returns true if the connection has been initialized.
    def open?
      state == :open
    end

    # Returns true if the connection has been closed.
    def closed?
      state == :closed
    end

    # Returns true if the connection is in the process of being initialized
    # (e.g., it is not closed, but is not yet fully open).
    def opening?
      !(open? || closed?)
    end

    # Attempts to establish an SFTP connection over the SSH session given when
    # this object was instantiated. If the object is already open (or opening),
    # this does nothing.
    #
    # This method does not block, and will return immediately. If you pass a
    # block to it, that block will be invoked when the connection has been
    # fully established. Thus, you can do something like this:
    #
    #   base.connect do
    #     puts "open!"
    #   end
    #
    # If you just want to block until the connection is ready, you can do this:
    #
    #   base.connect
    #   base.loop { base.opening? }
    #   puts "open!"
    def connect(&block)
      return unless state == :closed
      @state = :opening
      @channel = session.open_channel(&method(:when_channel_confirmed))
      @packet_length = nil
      @protocol = nil
      @on_ready = block
    end

    alias :loop_forever :loop

    # Runs the SSH event loop while the given block returns true. This lets
    # you set up a state machine and then "fire it off". If you do not specify
    # a block, the event loop will run for as long as there are any pending
    # SFTP requests. This makes it easy to do thing like this:
    #
    #   base.remove("/path/to/file")
    #   base.loop
    def loop(&block)
      block ||= Proc.new { pending_requests.any? }
      session.loop(&block)
    end

    # Formats, constructs, and sends an SFTP packet of the given type and with
    # the given data. This does not block, but merely enqueues the packet for
    # sending and returns.
    #
    # You should probably use the operation methods, rather than building and
    # sending the packet directly. (See #open, #close, etc.)
    def send_packet(type, *args)
      data = Net::SSH::Buffer.from(*args)
      msg = Net::SSH::Buffer.from(:long, data.length+1, :byte, type, :raw, data)
      channel.send_data(msg.to_s)
    end

    public

      # :call-seq:
      #   open(path, flags="r", options={}) -> request
      #   open(path, flags="r", options={}) { |response| ... } -> request
      #
      # Opens a file on the remote server. The +flags+ parameter determines
      # how the flag is open, and accepts the same format as IO#open (e.g.,
      # either a string like "r" or "w", or a combination of the IO constants).
      # The +options+ parameter is a hash of attributes to be associated
      # with the file, and varies greatly depending on the SFTP protocol
      # version in use, but some (like :permissions) are always available.
      #
      # Returns immediately with a Request object. If a block is given, it will
      # be invoked when the server responds, with a Response object as the only
      # parameter. The :handle property of the response is the handle of the
      # opened file, and may be passed to other methods (like #close, #read,
      # #write, and so forth).
      #
      #   base.open("/path/to/file") do |response|
      #     raise "fail!" unless response.ok?
      #     base.close(response[:handle])
      #   end
      #   base.loop
      def open(path, flags="r", options={}, &callback)
        request :open, path, flags, options, &callback
      end

      # :call-seq:
      #   close(handle) -> request
      #   close(handle) { |response| ... } -> request
      #
      # Closes an open handle, whether obtained via #open, or #opendir. Returns
      # immediately with a Request object. If a block is given, it will be
      # invoked when the server responds.
      #
      #   base.open("/path/to/file") do |response|
      #     raise "fail!" unless response.ok?
      #     base.close(response[:handle])
      #   end
      #   base.loop
      def close(handle, &callback)
        request :close, handle, &callback
      end

      # :call-seq:
      #   read(handle, offset, length) -> request
      #   read(handle, offset, length) { |response| ... } -> request
      #
      # Requests that +length+ bytes, starting at +offset+ bytes from the
      # beginning of the file, be read from the file identified by
      # +handle+. (The +handle+ should be a value obtained via the #open
      # method.)  Returns immediately with a Request object. If a block is
      # given, it will be invoked when the server responds.
      #
      # The :data property of the response will contain the requested data,
      # assuming the call was successful.
      #
      #   request = base.read(handle, 0, 1024) do |response|
      #     if response.eof?
      #       puts "end of file reached before reading any data"
      #     elsif !response.ok?
      #       puts "error (#{response})"
      #     else
      #       print(response[:data])
      #     end
      #   end
      #   request.wait
      #
      # To read an entire file will usually require multiple calls to #read,
      # unless you know in advance how large the file is.
      def read(handle, offset, length, &callback)
        request :read, handle, offset, length, &callback
      end

      # :call-seq:
      #   write(handle, offset, data) -> request
      #   write(handle, offset, data) { |response| ... } -> request
      #
      # Requests that +data+ be written to the file identified by +handle+,
      # starting at +offset+ bytes from the start of the file. The file must
      # have been opened for writing via #open. Returns immediately with a
      # Request object. If a block is given, it will be invoked when the
      # server responds.
      #
      #   request = base.write(handle, 0, "hello, world!\n")
      #   request.wait
      def write(handle, offset, data, &callback)
        request :write, handle, offset, data, &callback
      end

      # :call-seq:
      #   lstat(path, flags=nil) -> request
      #   lstat(path, flags=nil) { |response| ... } -> request
      #
      # This method is identical to the #stat method, with the exception that
      # it will not follow symbolic links (thus allowing you to stat the
      # link itself, rather than what it refers to). The +flags+ parameter
      # is not used in SFTP protocol versions prior to 4, and will be ignored
      # in those versions of the protocol that do not use it. For those that
      # do, however, you may provide hints as to which file proprties you wish
      # to query (e.g., if all you want is permissions, you could pass the
      # Net::SFTP::Protocol::V04::Attributes::F_PERMISSIONS flag as the value
      # for the +flags+ parameter).
      #
      # The method returns immediately with a Request object. If a block is given,
      # it will be invoked when the server responds. The :attrs property of
      # the response will contain an Attributes instance appropriate for the
      # the protocol version (see Protocol::V01::Attributes, Protocol::V04::Attributes,
      # and Protocol::V06::Attributes).
      #
      #   request = base.lstat("/path/to/file") do |response|
      #     raise "fail!" unless response.ok?
      #     puts "permissions: %04o" % response[:attrs].permissions
      #   end
      #   request.wait
      def lstat(path, flags=nil, &callback)
        request :lstat, path, flags, &callback
      end

      # The fstat method is identical to the #stat and #lstat methods, with
      # the exception that it takes a +handle+ as the first parameter, such
      # as would be obtained via the #open or #opendir methods. (See the #lstat
      # method for full documentation).
      def fstat(handle, flags=nil, &callback)
        request :fstat, handle, flags, &callback
      end

      # :call-seq:
      #    setstat(path, attrs) -> request
      #    setstat(path, attrs) { |response| ... } -> request
      #
      # This method may be used to set file metadata (such as permissions, or
      # user/group information) on a remote file. The exact metadata that may
      # be tweaked is dependent on the SFTP protocol version in use, but in
      # general you may set at least the permissions, user, and group. (See
      # Protocol::V01::Attributes, Protocol::V04::Attributes, and Protocol::V06::Attributes
      # for the full lists of attributes that may be set for the different
      # protocols.)
      #
      # The +attrs+ parameter is a hash, where the keys are symbols identifying
      # the attributes to set.
      #
      # The method returns immediately with a Request object. If a block is given,
      # it will be invoked when the server responds.
      #
      #   request = base.setstat("/path/to/file", :permissions => 0644)
      #   request.wait
      #   puts "success: #{request.response.ok?}"
      def setstat(path, attrs, &callback)
        request :setstat, path, attrs, &callback
      end

      # The fsetstat method is identical to the #setstat method, with the
      # exception that it takes a +handle+ as the first parameter, such as
      # would be obtained via the #open or #opendir methods. (See the
      # #setstat method for full documentation.)
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

      def block(handle, offset, length, mask, &callback)
        request :block, handle, offset, length, mask, &callback
      end

      def unblock(handle, offset, length, &callback)
        request :unblock, handle, offset, length, &callback
      end

    private

      attr_reader :input

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