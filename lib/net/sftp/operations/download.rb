require 'pathname'
require 'net/ssh/loggable'

module Net; module SFTP; module Operations

  # A general purpose downloader module for Net::SFTP. It can download files
  # into IO objects, or directly to files on the local file system. It can
  # even download entire directory trees via SFTP, and provides a flexible
  # progress reporting mechanism.
  #
  # To download a single file from the remote server, simply specify both the
  # remote and local paths:
  #
  #   downloader = sftp.download("/path/to/remote.txt", "/path/to/local.txt")
  #
  # By default, this operates asynchronously, so if you want to block until
  # the download finishes, you can use the 'bang' variant:
  #
  #   sftp.download!("/path/to/remote.txt", "/path/to/local.txt")
  #
  # Or, if you have multiple downloads that you want to run in parallel, you can
  # employ the #wait method of the returned object:
  #
  #   dls = %w(file1 file2 file3).map { |f| sftp.download("remote/#{f}", f) }
  #   dls.each { |d| d.wait }
  #
  # To download an entire directory tree, recursively, simply specify :recursive => true:
  #
  #   sftp.download!("/path/to/remotedir", "/path/to/local", :recursive => true)
  #
  # This will download "/path/to/remotedir", its contents, its subdirectories,
  # and their contents, recursively, to "/path/to/local" on the local host.
  # (If you specify :recursive => true and the source is not a directory,
  # you'll get an error!)
  #
  # If you want to pull the contents of a file on the remote server, and store
  # the data in memory rather than immediately to disk, you can pass an IO
  # object as the destination:
  #
  #   require 'stringio'
  #   io = StringIO.new
  #   sftp.download!("/path/to/remote", io)
  #
  # This will only work for single-file downloads. Trying to do so with
  # :recursive => true will cause an error.
  #
  # The following options are supported:
  #
  # * <tt>:progress</tt> - either a block or an object to act as a progress
  #   callback. See the discussion of "progress monitoring" below.
  # * <tt>:requests</tt> - the number of pending SFTP requests to allow at
  #   any given time. When downloading a single file, this is the number of
  #   reads kept in flight and defaults to 64. When downloading an entire
  #   directory tree recursively, it is the number of files and directories
  #   transferred at once and defaults to 16. Setting this higher might
  #   improve throughput, particularly on high-latency links. Reducing it
  #   will reduce throughput.
  # * <tt>:read_size</tt> - the maximum number of bytes to read at a time
  #   from the source. Increasing this value might improve throughput. It
  #   defaults to 32,000 bytes.
  # * <tt>:preserve</tt> - if true, the local files and directories get the
  #   access and modification times of the remote ones, and their permissions
  #   are set exactly, even on files that already exist and regardless of the
  #   umask.
  #
  # Like OpenSSH's sftp client, new local files and directories are created
  # with the permissions of the remote ones, without setuid, setgid and sticky
  # bits and subject to the umask. Nothing is set when +local+ is an IO object.
  # If the remote attributes can't be read, the download goes ahead with
  # default permissions; if they can't be applied locally, a warning is logged
  # and the download still succeeds.
  #
  # == Progress Monitoring
  #
  # Sometimes it is desirable to track the progress of a download. There are
  # two ways to do this: either using a callback block, or a special custom
  # object.
  #
  # Using a block it's pretty straightforward:
  #
  #   sftp.download!("remote", "local") do |event, downloader, *args|
  #     case event
  #     when :open then
  #       # args[0] : file metadata
  #       puts "starting download: #{args[0].remote} -> #{args[0].local} (#{args[0].size} bytes}"
  #     when :get then
  #       # args[0] : file metadata
  #       # args[1] : byte offset in remote file
  #       # args[2] : data that was received
  #       puts "writing #{args[2].length} bytes to #{args[0].local} starting at #{args[1]}"
  #     when :close then
  #       # args[0] : file metadata
  #       puts "finished with #{args[0].remote}"
  #     when :mkdir then
  #       # args[0] : local path name
  #       puts "creating directory #{args[0]}"
  #     when :finish then
  #       puts "all done!"
  #     end
  #   end
  #
  # However, for more complex implementations (e.g., GUI interfaces and such)
  # a block can become cumbersome. In those cases, you can create custom
  # handler objects that respond to certain methods, and then pass your handler
  # to the downloader:
  #
  #   class CustomHandler
  #     def on_open(downloader, file)
  #       puts "starting download: #{file.remote} -> #{file.local} (#{file.size} bytes)"
  #     end
  #
  #     def on_get(downloader, file, offset, data)
  #       puts "writing #{data.length} bytes to #{file.local} starting at #{offset}"
  #     end
  #
  #     def on_close(downloader, file)
  #       puts "finished with #{file.remote}"
  #     end
  #
  #     def on_mkdir(downloader, path)
  #       puts "creating directory #{path}"
  #     end
  #
  #     def on_finish(downloader)
  #       puts "all done!"
  #     end
  #   end
  #
  #   sftp.download!("remote", "local", :progress => CustomHandler.new)
  #
  # If you omit any of those methods, the progress updates for those missing
  # events will be ignored. You can create a catchall method named "call" for
  # those, instead.
  class Download
    include Net::SSH::Loggable

    # The destination of the download (the name of a file or directory on
    # the local server, or an IO object)
    attr_reader :local

    # The source of the download (the name of a file or directory on the
    # remote server)
    attr_reader :remote

    # The hash of options that was given to this Download instance.
    attr_reader :options

    # The SFTP session instance that drives this download.
    attr_reader :sftp

    # The properties hash for this object
    attr_reader :properties

    # Instantiates a new downloader process on top of the given SFTP session.
    # +local+ is either an IO object that should receive the data, or a string
    # identifying the target file or directory on the local host. +remote+ is
    # a string identifying the location on the remote host that the download
    # should source.
    #
    # This will return immediately, and requires that the SSH event loop be
    # run in order to effect the download. (See #wait.)
    def initialize(sftp, local, remote, options={}, &progress)
      local = local.to_path if local.is_a?(Pathname)
      remote = remote.to_path if remote.is_a?(Pathname)

      @sftp = sftp
      @local = local
      @remote = remote
      @progress = progress || options[:progress]
      @options = options
      @active = 0
      @directories = []
      @properties = options[:properties] || {}
      requests
      read_size

      self.logger = sftp.logger

      if recursive? && local.respond_to?(:write)
        raise ArgumentError, "cannot download a directory tree in-memory"
      end

      @stack = [Entry.new(remote, local, recursive?)]
      process_next_entry
    end

    # Returns the value of the :recursive key in the options hash that was
    # given when the object was instantiated.
    def recursive?
      options[:recursive]
    end

    # Returns true if there are any active requests or pending files or
    # directories.
    def active?
      @active > 0 || stack.any?
    end

    # Forces the transfer to stop.
    def abort!
      @active = 0
      @stack.clear
    end

    # Runs the SSH event loop for as long as the downloader is active (see
    # #active?). This can be used to block until the download completes.
    def wait
      sftp.loop { active? }
      self
    end

    # Returns the property with the given name. This allows Download instances
    # to store their own state when used as part of a state machine.
    def [](name)
      @properties[name.to_sym]
    end

    # Sets the given property to the given name. This allows Download instances
    # to store their own state when used as part of a state machine.
    def []=(name, value)
      @properties[name.to_sym] = value
    end

    private

      # A simple struct for encapsulating information about a single remote
      # file or directory that needs to be downloaded.
      Entry = Struct.new(:remote, :local, :directory, :size, :handle, :offset, :sink,
                         :next_read, :pending, :window, :chunks, :eof, :attributes)

      #--
      # "ruby -w" hates private attributes, so we have to do these longhand
      #++

      # The stack of Entry instances, indicating which files and directories
      # on the remote host remain to be downloaded.
      def stack; @stack; end

      # The progress handler for this instance. Possibly nil.
      def progress; @progress; end

      # The default read size.
      DEFAULT_READ_SIZE = 32_000

      # The number of bytes to read at a time from remote files.
      def read_size
        @read_size ||= positive_option(:read_size, DEFAULT_READ_SIZE)
      end

      # The number of simultaneous SFTP requests to use to effect the download.
      # Defaults to 16 for recursive downloads and 64 for single files.
      def requests
        @requests ||= positive_option(:requests, recursive? ? 16 : 64)
      end

      # The most reads a single file may have outstanding at once.
      def read_window_limit
        recursive? ? 1 : requests
      end

      def preserve?
        options[:preserve]
      end

      def positive_option(name, default)
        value = (options[name] || default).to_i
        raise ArgumentError, ":#{name} must be positive" unless value > 0

        value
      end

      # Enqueues as many files and directories from the stack as possible
      # (see #requests).
      def process_next_entry
        while stack.any? && requests > @active
          entry = stack.shift
          @active += 1

          if entry.directory
            update_progress(:mkdir, entry.local)
            refuse_symlink!(entry.local) if server_named?(entry) && ::File.symlink?(entry.local)
            created = !::File.directory?(entry.local)
            ::Dir.mkdir(entry.local, local_permissions(entry, 0777) | 0300) if created
            if created || preserve?
              @directories << entry
              stat_directory(entry) unless entry.attributes
            end
            request = sftp.opendir(entry.remote, &method(:on_opendir))
            request[:entry] = entry
          else
            open_file(entry)
          end
        end

        if !active?
          set_directory_attributes
          update_progress(:finish)
        end
      end

      # Only entries listed by readdir come with attributes.
      def stat_directory(entry)
        @active += 1
        sftp.stat(entry.remote) do |response|
          @active -= 1
          entry.attributes = remote_attributes(response, "stat #{entry.remote}")
          process_next_entry
        end
      end

      # Without the remote attributes the download goes ahead with default
      # permissions and no times, as it would for a server that never sent any.
      def remote_attributes(response, operation)
        return response[:attrs] if response.ok?

        debug { "#{operation} failed, using default attributes: #{response}" }
        nil
      end

      # Deepest directories first, after their contents; setting attributes on
      # a directory doesn't change its parent's modification time.
      def set_directory_attributes
        @directories.reverse_each do |entry|
          next unless entry.attributes

          permissions = local_permissions(entry, 0777)
          permissions &= ~::File.umask unless preserve?
          set_local_attributes(entry, permissions)
        end
        @directories.clear
      end

      # setuid, setgid and sticky bits are never applied, matching OpenSSH.
      def local_permissions(entry, default)
        permissions = entry.attributes && entry.attributes.permissions
        permissions ? permissions & 0777 : default
      end

      # Like OpenSSH's sftp client, failing to set attributes only warns; the
      # data has already been transferred.
      def set_local_attributes(entry, permissions)
        attempt_local("chmod", entry) { ::File.chmod(permissions, entry.local) } if permissions

        attributes = entry.attributes
        return unless preserve? && attributes && attributes.atime && attributes.mtime
        attempt_local("utime", entry) { ::File.utime(attributes.atime, attributes.mtime, entry.local) }
      end

      def attempt_local(operation, entry)
        yield
      rescue SystemCallError => e
        lwarn { "#{operation} #{entry.local} failed: #{e.message}" }
      end

      # Called when a remote directory is "opened" for reading, e.g. to
      # enumerate its contents. Starts an readdir operation if the opendir
      # operation was successful.
      def on_opendir(response)
        entry = response.request[:entry]
        raise  StatusException.new(response, "opendir #{entry.remote}") unless response.ok?
        entry.handle = response[:handle]
        request = sftp.readdir(response[:handle], &method(:on_readdir))
        request[:parent] = entry
      end

      # Called when the next batch of items is read from a directory on the
      # remote server. If any items were read, they are added to the queue
      # and #process_next_entry is called.
      def on_readdir(response)
        entry = response.request[:parent]
        if response.eof?
          request = sftp.close(entry.handle, &method(:on_closedir))
          request[:parent] = entry
        elsif !response.ok?
          raise StatusException.new(response, "readdir #{entry.remote}")
        else
          response[:names].each do |item|
            next if item.name == "." || item.name == ".."
            validate_entry_name!(entry, item.name)
            child = Entry.new(::File.join(entry.remote, item.name), ::File.join(entry.local, item.name), item.directory?, item.attributes.size)
            child.attributes = item.attributes
            stack << child
          end

          # take this opportunity to enqueue more requests
          process_next_entry

          request = sftp.readdir(entry.handle, &method(:on_readdir))
          request[:parent] = entry
        end
      end

      # The name comes from the server, so anything but a single path component
      # would let a malicious server write outside the target directory.
      def validate_entry_name!(entry, name)
        if name.empty? || name.include?("/") || name.include?("\0") ||
           (::File::ALT_SEPARATOR && name.include?(::File::ALT_SEPARATOR))
          raise Net::SFTP::Exception, "readdir #{entry.remote} returned an invalid file name: #{name.inspect}"
        end
      end

      # The caller's own +local+ may be a symlink on purpose; anything below it
      # was named by the server (net-sftp#162).
      def server_named?(entry)
        entry.local != local
      end

      # Like OpenSSH, the file is always created writable by its owner.
      def open_local_file(entry)
        permissions = local_permissions(entry, 0666) | 0200
        return ::File.open(entry.local, "wb", permissions) unless server_named?(entry) && defined?(::File::NOFOLLOW)

        begin
          ::File.open(entry.local, "wb", permissions, :flags => ::File::NOFOLLOW)
        rescue SystemCallError
          raise unless ::File.symlink?(entry.local)
          refuse_symlink!(entry.local)
        end
      end

      def refuse_symlink!(path)
        raise Net::SFTP::Exception, "#{path} is a symlink, refusing to follow it"
      end

      # Called when a file is to be opened for reading from the remote server.
      def open_file(entry)
        update_progress(:open, entry)
        request = sftp.open(entry.remote, &method(:on_open))
        request[:entry] = entry
      end

      # Called when a directory handle is closed.
      def on_closedir(response)
        @active -= 1
        entry = response.request[:parent]
        raise StatusException.new(response, "close #{entry.remote}") unless response.ok?
        process_next_entry
      end

      # Called when a file has been opened. This will call #request_reads
      # to initiate the data transfer.
      def on_open(response)
        entry = response.request[:entry]
        raise StatusException.new(response, "open #{entry.remote}") unless response.ok?

        entry.handle = response[:handle]
        if entry.attributes || entry.local.respond_to?(:write)
          start_download(entry)
        else
          request = sftp.fstat(entry.handle, &method(:on_fstat))
          request[:entry] = entry
        end
      end

      # Called when the attributes of a file opened by #open_file arrive.
      def on_fstat(response)
        entry = response.request[:entry]
        entry.attributes = remote_attributes(response, "fstat #{entry.remote}")
        start_download(entry)
      end

      def start_download(entry)
        entry.sink = entry.local.respond_to?(:write) ? entry.local : open_local_file(entry)
        entry.offset = 0
        entry.next_read = 0
        entry.pending = 0
        entry.window = 1
        entry.chunks = {}

        request_reads(entry)
      end

      # Keeps up to entry.window reads of #read_size bytes outstanding until
      # the server reports EOF. The window starts at one and grows with each
      # data reply, so small files don't cost a burst of reads past their end.
      def request_reads(entry)
        while !entry.eof && entry.pending < entry.window
          read_range(entry, entry.next_read, read_size)
          entry.next_read += read_size
        end
      end

      def read_range(entry, offset, length)
        entry.pending += 1
        request = sftp.read(entry.handle, offset, length, &method(:on_read))
        request[:entry] = entry
        request[:offset] = offset
        request[:length] = length
      end

      # Called when a read from a file finishes. Replies can arrive out of
      # order, so data is buffered until everything before it has been
      # written. Once the server has reported EOF and no reads are left
      # outstanding, the file is closed.
      def on_read(response)
        entry = response.request[:entry]
        entry.pending -= 1

        if response.eof?
          entry.eof = true
        elsif !response.ok?
          raise StatusException.new(response, "read #{entry.remote}")
        else
          offset = response.request[:offset]
          length = response.request[:length]
          data = response[:data]

          if data.empty? || data.bytesize > length
            raise Net::SFTP::Exception, "read #{entry.remote} returned #{data.bytesize} bytes for a #{length} byte request"
          end

          # Servers may return less than asked for without being at EOF, and
          # the reads after this one have already been sent.
          read_range(entry, offset + data.bytesize, length - data.bytesize) if data.bytesize < length

          entry.chunks[offset] = data
          write_buffered_chunks(entry)
          entry.window += 1 if entry.window < read_window_limit
        end

        request_reads(entry)
        close_file(entry) if entry.pending.zero?
      end

      def write_buffered_chunks(entry)
        while (data = entry.chunks.delete(entry.offset))
          update_progress(:get, entry, entry.offset, data)
          entry.sink.write(data)
          entry.offset += data.bytesize
        end
      end

      def close_file(entry)
        if entry.chunks.any?
          raise Net::SFTP::Exception, "read #{entry.remote} hit EOF at #{entry.offset} but the server returned data beyond it"
        end

        update_progress(:close, entry)
        # The caller's IO stays open, but is flushed so its data is written when download! returns.
        if entry.sink.equal?(local)
          entry.sink.flush if entry.sink.respond_to?(:flush)
        else
          entry.sink.close
        end
        unless entry.local.respond_to?(:write)
          set_local_attributes(entry, preserve? ? local_permissions(entry, nil) : nil)
        end
        request = sftp.close(entry.handle, &method(:on_close))
        request[:entry] = entry
      end

      # Called when a file handle is closed.
      def on_close(response)
        @active -= 1
        entry = response.request[:entry]
        raise StatusException.new(response, "close #{entry.remote}") unless response.ok?
        process_next_entry
      end

      # If a progress callback or object has been set, this will report
      # the progress to that callback or object.
      def update_progress(hook, *args)
        on = "on_#{hook}"
        if progress.respond_to?(on)
          progress.send(on, self, *args)
        elsif progress.respond_to?(:call)
          progress.call(hook, self, *args)
        end
      end
  end

end; end; end
