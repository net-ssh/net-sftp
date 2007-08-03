require 'net/ssh/loggable'

module Net; module SFTP; module Operations

  class Upload
    include Net::SSH::Loggable

    attr_reader :local
    attr_reader :remote
    attr_reader :size

    def initialize(base, local, remote, open_options={}, &progress)
      @base = base
      @local = local
      @remote = remote
      @progress = progress

      self.logger = base.logger

      debug { "opening #{remote} for writing" }
      base.open(remote, "w", open_options, &method(:on_open))
    end

    private

      WRITER_REQUESTS = 4
      READ_CHUNK_SIZE = 32000

      attr_reader :base
      attr_reader :handle
      attr_reader :file
      attr_reader :offset
      attr_reader :progress
      attr_reader :active

      def on_open(response)
        raise "could not upload file: #{response}" unless response.ok?
        debug { "open #{remote} succeeded" }
        @handle = response[:handle]
        @file = File.open(local)
        @size = @file.stat.size
        @offset = 0
        @active = 0
        update_progress(:offset => 0)
        WRITER_REQUESTS.times { send_next_reader_request }
      end

      def on_write(response)
        raise "could not write chunk: #{status}" unless response.ok?
        @active -= 1
        update_progress(response.request)
        send_next_reader_request
      end

      def on_close(response)
        raise "could not close remote file: #{status}" unless response.ok?
        debug { "done uploading from #{local} to #{remote}" }
      end

      def send_next_reader_request
        if offset >= size
          if active <= 0
            file.close
            base.close(handle, &method(:on_close))
          end
        else
          @active += 1
          data = file.read(READ_CHUNK_SIZE)
          debug { "writing #{data.length} at #{offset}" }
          request = base.write(handle, offset, data, &method(:on_write))
          request[:offset] = (@offset += data.length)
        end
      end

      def update_progress(data)
        progress.call(self, data[:offset]) if progress
      end
  end

end; end; end
