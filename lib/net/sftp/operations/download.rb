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
            Dir.mkdir(entry.local) unless File.directory?(entry.local)
            request = base.opendir(entry.remote, &method(:on_opendir))
            request[:entry] = entry
          else
            open_file(entry)
          end
        end

        update_progress(:finish) if !active?
      end

      def on_opendir(status)
        entry = status.request[:entry]
        raise "opendir #{entry.remote}: #{status}" unless status.ok?
        entry.handle = status[:handle]
        request = base.readdir(status[:handle], &method(:on_readdir))
        request[:parent] = entry
      end

      def on_readdir(status)
        entry = status.request[:parent]
        if status.eof?
          request = base.close(entry.handle, &method(:on_closedir))
          request[:parent] = entry
        elsif !status.ok?
          raise "readdir #{entry.remote}: #{status}"
        else
          status[:names].each do |item|
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

      def on_closedir(status)
        @active -= 1
        entry = status.request[:parent]
        raise "close #{entry.remote}: #{status}" unless status.ok?
        process_next_entry
      end

      def on_open(status)
        entry = status.request[:entry]
        raise "open #{entry.remote}: #{status}" unless status.ok?

        entry.handle = status[:handle]
        entry.sink = File.open(entry.local, "w")
        entry.offset = 0

        download_next_chunk(entry)
      end

      def download_next_chunk(entry)
        update_progress(:read, entry, entry.offset)

        size = options[:read_size] || 32_000
        request = base.read(entry.handle, entry.offset, size, &method(:on_read))
        entry.offset += size
        request[:entry] = entry
      end

      def on_read(status)
        entry = status.request[:entry]

        if status.eof? || (entry.size && entry.offset >= entry.size)
          update_progress(:close, entry)
          entry.sink.close
          request = base.close(entry.handle, &method(:on_close))
          request[:entry] = entry
        elsif !status.ok?
          raise "read #{entry.remote}: #{status}"
        else
          entry.sink.write(status[:data])
          download_next_chunk(entry)
        end
      end

      def on_close(status)
        @active -= 1
        entry = status.request[:entry]
        raise "close #{entry.remote}: #{status}" unless status.ok?
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
