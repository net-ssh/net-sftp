require 'net/sftp/errors'

module Net; module SFTP; module Protocol

  # Several SFTP structures are a 32-bit item count followed by that many
  # items. Net::SSH::Buffer returns nil instead of raising when a read runs
  # past the end of the data, so a loop over an unchecked count from the
  # server keeps allocating long after the packet is exhausted.
  module BoundedRead
    # Reads an item count from +buffer+ and raises Net::SFTP::Exception if it
    # is missing, or larger than the remaining bytes could hold given that
    # each item takes at least +min_item_size+ bytes.
    def read_bounded_count!(buffer, min_item_size, what)
      count = buffer.read_long
      raise Net::SFTP::Exception, "truncated packet: missing #{what} count" if count.nil?

      if count > buffer.available / min_item_size
        raise Net::SFTP::Exception, "server sent #{count} #{what} entries in only #{buffer.available} bytes"
      end

      count
    end
  end

end; end; end
