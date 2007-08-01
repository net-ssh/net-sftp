require 'net/ssh/buffer'

module Net; module SFTP

  class Packet < Net::SSH::Buffer
    attr_reader :type

    def initialize(data)
      super
      @type = read_byte
    end
  end

end; end