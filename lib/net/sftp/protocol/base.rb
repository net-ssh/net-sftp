require 'net/ssh/loggable'
require 'net/sftp/constants'

module Net; module SFTP; module Protocol

  class Base
    include Net::SSH::Loggable
    include Net::SFTP::Constants

    attr_reader :session

    def initialize(session)
      @session = session
      self.logger = session.logger
      @request_id_counter = -1
    end

    private

      def send_request(type, *args)
        @request_id_counter += 1
        session.send_packet(type, :long, @request_id_counter, *args)
        return @request_id_counter
      end
  end

end; end; end