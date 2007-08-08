require 'net/sftp/constants'

module Net; module SFTP

  class Request
    include Constants

    attr_reader :session
    attr_reader :id
    attr_reader :type
    attr_reader :callback
    attr_reader :properties

    def initialize(session, type, id, &callback)
      @session, @id, @type, @callback = session, id, type, callback
      @properties = {}
    end

    def [](key)
      properties[key.to_sym]
    end

    def []=(key, value)
      properties[key.to_sym] = value
    end

    def pending?
      session.pending_requests.key?(id)
    end

    def wait
      session.loop { pending? }
      self
    end

    def respond_to(packet)
      if callback
        data = session.protocol.parse(packet)
        data[:type] = packet.type
        callback.call(Response.new(self, data))
      end
    end
  end

end; end