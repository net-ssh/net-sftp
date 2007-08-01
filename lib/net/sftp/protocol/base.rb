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

    def parse(packet)
      case packet.type
      when FXP_STATUS then parse_status_packet(packet)
      when FXP_HANDLE then parse_handle_packet(packet)
      when FXP_DATA   then parse_data_packet(packet)
      when FXP_NAME   then parse_name_packet(packet)
      when FXP_ATTRS  then parse_attrs_packet(packet)
      else raise NotImplementedError, "unknown packet type: #{packet.type}"
      end
    end

    private

      MAP = {
        FXP_STATUS  => :status,
        FXP_HANDLE  => :handle,
        FXP_DATA    => :data,
        FXP_NAME    => :name,
        FXP_ATTRS   => :attrs
      }

      def send_request(type, *args)
        @request_id_counter += 1
        session.send_packet(type, :long, @request_id_counter, *args)
        return @request_id_counter
      end
  end

end; end; end