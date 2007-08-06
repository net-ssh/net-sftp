require 'net/ssh/loggable'

module Net; module SFTP; module Operations

  class Upload
    include Net::SSH::Loggable

    attr_reader :local
    attr_reader :remote
    attr_reader :options

    def initialize(base, local, remote, options={}, &progress)
      @base = base
      @local = local
      @remote = remote
      @progress = progress || options[:progress]
      @options = options
      @active = 0

      self.logger = base.logger

      @uploads = []

      if recursive?
        raise "expected a directory to upload" unless File.directory?(local)
        @stack = [entries_for(local)]
        @local_cwd = local
        @remote_cwd = remote

        base.mkdir(remote) do
          (options[:requests] || RECURSIVE_READERS).to_i.times do
            break unless process_next_entry
          end
        end
      else
        raise "expected a file to upload" unless local.respond_to?(:read) || File.file?(local)
        @stack = [[local]]
        process_next_entry
      end
    end

    def recursive?
      options[:recursive]
    end

    private

      attr_reader :base
      attr_reader :progress

      LiveFile = Struct.new(:local, :remote, :io, :size, :handle)

      DEFAULT_READ_SIZE   = 32_000
      SINGLE_FILE_READERS = 2
      RECURSIVE_READERS   = 16

      def process_next_entry
        if @stack.empty?
          if @uploads.any?
            write_next_chunk(@uploads.first)
          elsif @active.zero?
            update_progress(:finish)
          end
          return false
        elsif @stack.last.empty?
          @stack.pop
          @local_cwd = File.dirname(@local_cwd)
          @remote_cwd = File.dirname(@remote_cwd)
          process_next_entry
        elsif recursive?
          entry = @stack.last.shift
          lpath = File.join(@local_cwd, entry)
          rpath = File.join(@remote_cwd, entry)

          if File.directory?(lpath)
            @stack.push(entries_for(lpath))
            @local_cwd = lpath
            @remote_cwd = rpath

            @active += 1
            update_progress(:mkdir, rpath)
            request = base.mkdir(rpath, &method(:on_mkdir))
            request[:dir] = rpath
          else
            open_file(lpath, rpath)
          end
        else
          open_file(@stack.pop.first, remote)
        end
        return true
      end

      def open_file(local, remote)
        @active += 1

        if local.respond_to?(:read)
          file = local
          name = options[:name] || "<memory>"
        else
          file = File.open(local)
          name = local
        end

        if file.respond_to?(:stat)
          size = file.stat.size
        else
          size = file.size
        end

        request = base.open(remote, "w", &method(:on_open))
        request[:file] = LiveFile.new(name, remote, file, size)

        update_progress(:open, request[:file])
      end

      def on_mkdir(response)
        @active -= 1
        process_next_entry
      end

      def on_open(response)
        @active -= 1
        file = response.request[:file]
        raise "open #{file.remote}: #{response}" unless response.ok?

        file.handle = response[:handle]

        @uploads << file
        write_next_chunk(file)

        if !recursive?
          (options[:requests] || SINGLE_FILE_READERS).to_i.times { write_next_chunk(file) }
        end
      end

      def on_write(response)
        @active -= 1
        file = response.request[:file]
        raise "write #{file.remote}: #{response}" unless response.ok?
        write_next_chunk(file)
      end

      def on_close(response)
        @active -= 1
        file = response.request[:file]
        raise "close #{file.remote}: #{response}" unless response.ok?
        process_next_entry
      end

      def write_next_chunk(file)
        if file.io.nil?
          process_next_entry
        else
          @active += 1
          offset = file.io.pos
          data = file.io.read(options[:read_size] || DEFAULT_READ_SIZE)
          if data.nil?
            update_progress(:close, file)
            request = base.close(file.handle, &method(:on_close))
            file.io.close
            file.io = nil
            @uploads.delete(file)
          else
            update_progress(:write, file, offset, data)
            request = base.write(file.handle, offset, data, &method(:on_write))
            request[:file] = file
          end
        end
      end

      def entries_for(local)
        Dir.entries(local).reject { |v| %w(. ..).include?(v) }
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
