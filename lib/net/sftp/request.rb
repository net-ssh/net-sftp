require 'net/sftp/constants'
require 'net/sftp/response'

module Net; module SFTP

  class Request
    include Constants

    attr_reader :session
    attr_reader :id
    attr_reader :type
    attr_reader :callback
    attr_reader :properties
    attr_reader :response

    def initialize(session, type, id, &callback)
      @session, @id, @type, @callback = session, id, type, callback
      @response = nil
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
      data = session.protocol.parse(packet)
      data[:type] = packet.type
      @response = Response.new(self, data)

      callback.call(@response) if callback
    end
  end

end; end