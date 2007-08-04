require 'net/ssh/loggable'

module Net; module SFTP; module Operations

  class Upload
    include Net::SSH::Loggable

    attr_reader :local
    attr_reader :remote
    attr_reader :size
    attr_reader :options

    def initialize(base, local, remote, options={}, &progress)
      @base = base
      @local = local
      @remote = remote
      @progress = progress || options[:progress]
      @options = options

      self.logger = base.logger

      @file = local.respond_to?(:read) ? local : File.open(local)
      @size = @file.respond_to?(:size) ? @file.size : @file.stat.size

      debug { "opening #{remote} for writing" }
      base.open(remote, "w", &method(:on_open))
    end

    def preserve?
      options[:preserve]
    end

    private

      REQUESTS  = 4
      READ_SIZE = 16 * 1024

      attr_reader :base
      attr_reader :handle
      attr_reader :file
      attr_reader :offset
      attr_reader :progress
      attr_reader :active

      def attributes
        return {} unless preserve? && file.respond_to?(:stat)

        { :permissions => file.stat.mode,
          :atime       => file.stat.atime.to_i,
          :ctime       => file.stat.ctime.to_i,
          :mtime       => file.stat.mtime.to_i }
      end

      def on_open(response)
        raise "could not upload file: #{response}" unless response.ok?
        debug { "open #{remote} succeeded" }
        @handle = response[:handle]
        @offset = @active = 0
        update_progress(:start_transfer, self)
        (options[:requests] || REQUESTS).times { send_next_reader_request }
      end

      def on_write(response)
        raise "could not write chunk: #{status}" unless response.ok?
        @active -= 1
        update_progress(:update_transfer, self, response.request[:offset])
        send_next_reader_request
      end

      def on_setstat(response)
        raise "could not preserve file attributes: #{response}" unless response.ok?
        finish
      end

      def on_close(response)
        raise "could not close remote file: #{response}" unless response.ok?
        if preserve?
          base.setstat(remote, attributes, &method(:on_setstat))
        else
          finish
        end
      end

      def finish
        file.close
        update_progress(:finish_transfer, self)
        debug { "done uploading from #{local} to #{remote}" }
      end

      def send_next_reader_request
        if offset >= size
          if active <= 0
            base.close(handle, &method(:on_close))
          end
        else
          @active += 1
          data = file.read(options[:read_size] || READ_SIZE)
          debug { "writing #{data.length} at #{offset}" }
          request = base.write(handle, offset, data, &method(:on_write))
          request[:offset] = (@offset += data.length)
        end
      end

      def update_progress(hook, *args)
        if progress.respond_to?(hook)
          progress.send(hook, *args)
        elsif progress.respond_to?(:call)
          progress.call(hook, *args)
        end
      end
  end

end; end; end
