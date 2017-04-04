require 'net/sftp/protocol/06/base'

module Net; module SFTP; module Protocol; module V06

  # Wraps the low-level SFTP calls for version 6 of the SFTP protocol.
  #
  # None of these protocol methods block--all of them return immediately,
  # requiring the SSH event loop to be run while the server response is
  # pending.
  #
  # You will almost certainly never need to use this driver directly. Please
  # see Net::SFTP::Session for the recommended interface.
  class Extended < V06::Base

    # Parses the given "md5-hash" FXP_EXTENDED_REPL packet and returns a
    # hash with one key, :md5, which references the computed hash.
    def parse_md5_packet(data)
      md5 = ""

      if !data.empty?
        md5 = data.read_string
      end

      { :md5 => md5 }
    end

    # Parses the given "check-file" FXP_EXTENDED_REPL packet and returns a hash
    # with two keys, :algo, which references the hash algorithm used and
    # :hashes which references the computed hashes.
    def parse_hash_packet(data)
      hashes = []

      algo = data.read_string
      size = case algo
        when "md5"    then 128
        when "sha256" then 256
        when "sha384" then 284
        when "sha512" then 512
        else raise NotImplementedError, "unsupported algorithm: #{algo}"
      end

      while !data.eof? do
        hashes << data.read(size)
      end

      { :algo => algo, :hashes => hashes }
    end

    # Parses the given "home-directory" FXP_EXTENDED_REPL packet and returns a
    # hash with one key, :home, which references the home directory returned by
    # the server.
    def parse_home_packet(data)
      { :home => data.read_string }
    end

    # Parses the given FXP_EXTENDED_REPL packet and returns a hash, with
    # :extension key, which references SFTP extension and the associated keys
    def parse_extented_reply_packet(packet)
       packet.read_string do |extension|
         data = packet.remainder_as_buffer
         parsed_packet = case extension
           when "md5-hash"       then parse_md5_packet(data)
           when "check-file"     then parse_hash_packet(data)
           when "home-directory" then parse_home_packet(data)
           else raise NotImplementedError, "unknown packet type: #{extension}"
         end
       end

      { :extension => extension }.merge(parsed_packet)
    end

    # Sends a FXP_EXTENDED packet to the server to request MD5 checksum
    # computation for file (or portion of file) obtained on the given +handle+,
    # for the given byte +offset+ and +length+. The +quick_hash+ parameter is
    # the hash over the first 2048 bytes of the data. It allows the server to
    # quickly check if it is worth the resources to hash a big file.
    def md5(handle, offset, length, quick_hash)
      send_request(FXP_EXTENDED, :string, "md5-hash-handle", :int64, offset, :int64, length, :string, quick_hash)
    end

    # Sends a FXP_EXTENDED packet to the server to request checksum computation
    # for file (or portion of file) obtained on the given +handle+, for the
    # given byte +offset+ and +length+. The +block_size+ parameter is used to
    # compute over every +block_size+ block in the file. If the +block_size+ is
    # 0, then only one hash, over the entire range, is made.
    def hash(handle, offset, length, block_size=0)
      if block_size != 0 && block_size < 255
        block_size = 256
      end
      send_request(FXP_EXTENDED, :string, "check-file-handle", :string, handle, :string, "md5,sha256,sha384,sha512", :int64, offset, :int64, length, :long, block_size)
    end

    # Sends a FXP_EXTENDED packet to the server to request disk space availability
    # for the given +path+ location.
    def space_available(path)
      send_request(FXP_EXTENDED, :string, "space-available", :string, path)
    end

    # Sends a FXP_EXTENDED packet to the server to request home directory
    # for the given +username+.
    def home(username)
      send_request(FXP_EXTENDED, :string, "home-directory", :string, username)
    end

  end

end; end; end; end
