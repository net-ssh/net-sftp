require 'net/ssh/loggable'

module Net; module SFTP; module Operations

  class Download
    include Net::SSH::Loggable

    attr_reader :local
    attr_reader :remote
    attr_reader :options

    Entry = Struct.new(:remote, :local, :directory, :size, :handle, :offset, :sink)

    def initialize(base, local, remote, options={}, &progress)
      @base = base
      @local = local
      @remote = remote
      @progress = progress || options[:progress]
      @options = options
      @active = 0

      self.logger = base.logger

      if recursive? && local.respond_to?(:write)
        raise ArgumentError, "cannot download a directory tree in-memory"
      end

      @stack = [Entry.new(remote, local, recursive?)]
      process_next_entry
    end

    def recursive?
      options[:recursive]
    end

    def active?
      @active > 0
    end

    private

      attr_reader :base
      attr_reader :stack
      attr_reader :progress

      def requests
        options[:requests] || (recursive? ? 16 : 2)
      end

      def process_next_entry
        while stack.any? && requests > @active
          entry = stack.shift
          @active += 1

          if entry.directory
            update_progress(:mkdir, entry.local)
            Dir.mkdir(entry.local) unless File.directory?(entry.local)
            request = base.opendir(entry.remote, &method(:on_opendir))
            request[:entry] = entry
          else
            open_file(entry)
          end
        end

        update_progress(:finish) if !active?
      end

      def on_opendir(response)
        entry = response.request[:entry]
        raise "opendir #{entry.remote}: #{response}" unless response.ok?
        entry.handle = response[:handle]
        request = base.readdir(response[:handle], &method(:on_readdir))
        request[:parent] = entry
      end

      def on_readdir(response)
        entry = response.request[:parent]
        if response.eof?
          request = base.close(entry.handle, &method(:on_closedir))
          request[:parent] = entry
        elsif !response.ok?
          raise "readdir #{entry.remote}: #{response}"
        else
          response[:names].each do |item|
            next if item.name == "." || item.name == ".."
            stack << Entry.new(File.join(entry.remote, item.name), File.join(entry.local, item.name), item.directory?, item.attributes.size)
          end

          request = base.readdir(entry.handle, &method(:on_readdir))
          request[:parent] = entry
        end
      end

      def open_file(entry)
        update_progress(:open, entry)
        request = base.open(entry.remote, &method(:on_open))
        request[:entry] = entry
      end

      def on_closedir(response)
        @active -= 1
        entry = response.request[:parent]
        raise "close #{entry.remote}: #{response}" unless response.ok?
        process_next_entry
      end

      def on_open(response)
        entry = response.request[:entry]
        raise "open #{entry.remote}: #{response}" unless response.ok?

        entry.handle = response[:handle]
        entry.sink = entry.local.respond_to?(:write) ? entry.local : File.open(entry.local, "w")
        entry.offset = 0

        update_progress(:get, entry, 0, nil)
        download_next_chunk(entry)
      end

      def download_next_chunk(entry)
        size = options[:read_size] || 32_000
        request = base.read(entry.handle, entry.offset, size, &method(:on_read))
        request[:entry] = entry
        request[:offset] = entry.offset
        entry.offset += size
      end

      def on_read(response)
        entry = response.request[:entry]

        if response.eof?
          update_progress(:close, entry)
          entry.sink.close
          request = base.close(entry.handle, &method(:on_close))
          request[:entry] = entry
        elsif !response.ok?
          raise "read #{entry.remote}: #{response}"
        else
          update_progress(:get, entry, response.request[:offset] + response[:data].length, response[:data])
          entry.sink.write(response[:data])
          download_next_chunk(entry)
        end
      end

      def on_close(response)
        @active -= 1
        entry = response.request[:entry]
        raise "close #{entry.remote}: #{response}" unless response.ok?
        process_next_entry
      end

      def update_progress(hook, *args)
        on = :"on_#{hook}"
        if progress.respond_to?(on)
          progress.send(on, self, *args)
        elsif progress.respond_to?(:call)
          progress.call(hook, self, *args)
        end
      end
  end

end; end; end
