require 'net/ssh/loggable'

module Net; module SFTP; module Operations

  class UploadTree
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

      raise "expected a directory to upload" unless File.directory?(local)
      @stack = [entries_for(local)]
      @local_cwd = local

      @remote_cwd = remote
      @uploads = []

      mkdir_p(remote) { process_next_entries }
    end

    def preserve?
      options[:preserve]
    end

    private

      attr_reader :base
      attr_reader :progress

      LiveFile = Struct.new(:lpath, :rpath, :io, :handle)

      DEFAULT_READ_SIZE = 16 * 1024

      def mkdir_p(directory, attributes={})
        base.stat(directory) do |stat|
          if stat.ok?
            yield
          else
            base.mkdir(directory, attributes) do |mkdir|
              if mkdir.ok?
                yield
              else
                raise "could not create directory `#{directory}': #{mkdir}"
              end
            end
          end
        end
      end

      def process_next_entries
        (options[:requests] || 16).times do
          break unless process_next_entry
        end
      end

      def process_next_entry
        if @stack.empty?
          if @uploads.any?
            write_next_chunk(@uploads.first)
          else
            update_progress(:finish)
          end
          return false
        elsif @stack.last.empty?
          @stack.pop
          @local_cwd = File.dirname(@local_cwd)
          @remote_cwd = File.dirname(@remote_cwd)
          process_next_entry
        else
          entry = @stack.last.shift
          lpath = File.join(@local_cwd, entry)
          rpath = File.join(@remote_cwd, entry)

          if File.directory?(lpath)
            @stack.push(entries_for(lpath))
            @local_cwd = lpath
            @remote_cwd = rpath

            update_progress(:mkdir, rpath)
            request = base.mkdir(rpath, &method(:on_mkdir))
            request[:dir] = rpath
          else
            request = base.open(rpath, "w", &method(:on_open))
            request[:file] = LiveFile.new(lpath, rpath)
            update_progress(:open, request[:file])
          end
        end
        return true
      end

      def on_mkdir(response)
        rake "mkdir #{response.request[:dir]}: #{response}" unless response.ok?
        process_next_entry
      end

      def on_open(response)
        file = response.request[:file]
        raise "open #{file.rpath}: #{response}" unless response.ok?

        file.io = File.open(file.lpath)
        file.handle = response[:handle]

        @uploads << file
        write_next_chunk(file)
      end

      def on_write(response)
        file = response.request[:file]
        raise "write #{file.rpath}: #{response}" unless response.ok?
        write_next_chunk(file)
      end

      def on_close(response)
        file = response.request[:file]
        raise "close #{file.rpath}: #{response}" unless response.ok?
        process_next_entry
      end

      def write_next_chunk(file)
        if file.io.nil?
          process_next_entry
        else
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
