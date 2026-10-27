require "common"
require "tmpdir"
require "timeout"

class DownloadTest < Net::SFTP::TestCase
  FXP_DATA_CHUNK_SIZE = 1024

  def setup
    prepare_progress!
  end

  def test_download_file_should_transfer_remote_to_local
    local = "/path/to/local"
    remote = "/path/to/remote"
    text = "this is some text\n"

    expect_file_transfer(remote, text)

    file = StringIO.new
    File.stubs(:open).with(local, "wb").returns(file)

    assert_scripted_command { sftp.download(remote, local) }
    assert_equal text, file.string
    assert file.closed?
  end

  def test_download_file_should_transfer_remote_to_local_in_spite_of_fragmentation
    local = "/path/to/local"
    remote = "/path/to/remote"
    text = "this is some text\n"

    expect_file_transfer(remote, text, :fragment_len => 1)

    file = StringIO.new
    File.stubs(:open).with(local, "wb").returns(file)

    assert_scripted_command { sftp.download(remote, local) }
    assert_equal text, file.string
  end

  def test_download_file_should_handle_Pathname
    local = Pathname.new("/path/to/local").freeze
    remote = Pathname.new("/path/to/remote").freeze
    text = "this is some text\n"

    expect_file_transfer(remote.to_s, text)

    file = StringIO.new
    File.stubs(:open).with(local.to_s, "wb").returns(file)

    assert_scripted_command { sftp.download(remote, local) }
    assert_equal text, file.string
  end

  def test_download_large_file_should_transfer_remote_to_local
    local = "/path/to/local"
    remote = "/path/to/remote"
    text = "0123456789" * 1024

    file = prepare_large_file_download(local, remote, text)

    assert_scripted_command { sftp.download(remote, local, :read_size => 1024, :requests => 1) }
    assert_equal text, file.string
  end

  def test_download_large_file_should_handle_too_large_read_size
    local = "/path/to/local"
    remote = "/path/to/remote"
    text = "0123456789" * 1024

    # some servers put upper bound on the max read_size value and send less data than requested
    too_large_read_size = FXP_DATA_CHUNK_SIZE + 1
    file = prepare_large_file_download(local, remote, text, too_large_read_size)

    assert_scripted_command { sftp.download(remote, local, :read_size => too_large_read_size, :requests => 1) }
    assert_equal text, file.string
  end

  def test_download_large_file_with_progress_should_report_progress
    local = "/path/to/local"
    remote = "/path/to/remote"
    text = "0123456789" * 1024

    file = prepare_large_file_download(local, remote, text)

    assert_scripted_command do
      sftp.download(remote, local, :read_size => 1024, :requests => 1) do |*args|
        record_progress(args)
      end
    end

    assert_equal text, file.string

    assert_progress_reported_open :remote => "/path/to/remote"
    assert_progress_reported_get     0, 1024
    assert_progress_reported_get  1024, 1024
    assert_progress_reported_get  2048, 1024
    assert_progress_reported_get  3072, 1024
    assert_progress_reported_get  4096, 1024
    assert_progress_reported_get  5120, 1024
    assert_progress_reported_get  6144, 1024
    assert_progress_reported_get  7168, 1024
    assert_progress_reported_get  8192, 1024
    assert_progress_reported_get  9216, 1024
    assert_progress_reported_close
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_download_directory_should_mirror_directory_locally
    file1, file2 = prepare_directory_tree_download("/path/to/local", "/path/to/remote")

    assert_scripted_command do
      sftp.download("/path/to/remote", "/path/to/local", :recursive => true)
    end

    assert_equal "contents of file1", file1.string
    assert_equal "contents of file2", file2.string
  end

  def test_download_directory_with_progress_should_report_progress
    file1, file2 = prepare_directory_tree_download("/path/to/local", "/path/to/remote")

    assert_scripted_command do
      sftp.download("/path/to/remote", "/path/to/local", :recursive => true) do |*args|
        record_progress(args)
      end
    end

    assert_equal "contents of file1", file1.string
    assert_equal "contents of file2", file2.string

    assert_progress_reported_mkdir "/path/to/local"
    assert_progress_reported_mkdir "/path/to/local/subdir1"
    assert_progress_reported_open  :remote => "/path/to/remote/file1"
    assert_progress_reported_open  :remote => "/path/to/remote/subdir1/file2"
    assert_progress_reported_get   0, "contents of file1"
    assert_progress_reported_close :remote => "/path/to/remote/file1"
    assert_progress_reported_get   0, "contents of file2"
    assert_progress_reported_close :remote => "/path/to/remote/subdir1/file2"
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_download_file_should_transfer_remote_to_local_buffer
    remote = "/path/to/remote"
    text = "this is some text\n"

    expect_file_transfer(remote, text)

    local = StringIO.new

    assert_scripted_command { sftp.download(remote, local) }
    assert_equal text, local.string
    assert !local.closed?
  end

  def test_download_directory_to_buffer_should_fail
    expect_sftp_session :server_version => 3
    Net::SSH::Test::Extensions::IO.with_test_extension do
      assert_raises(ArgumentError) { sftp.download("/path/to/remote", StringIO.new, :recursive => true) }
    end
  end

  def test_download_should_reject_nonpositive_requests_and_read_size
    session = stub("sftp", :logger => nil)

    [{ :requests => 0 }, { :requests => -1 }, { :requests => "many" },
     { :read_size => 0 }, { :read_size => -1 }].each do |opts|
      assert_raises(ArgumentError, opts.inspect) do
        Net::SFTP::Operations::Download.new(session, StringIO.new, "/path/to/remote", opts)
      end
    end
  end

  def test_download_file_should_keep_requests_reads_in_flight
    text = "0123456789abcdef" * 256
    chunks = (0...4).map { |n| text.byteslice(n * 1024, 1024) }

    expect_sftp_session :server_version => 3 do |channel|
      expect_open(channel)
      channel.sends_packet(FXP_READ, :long, 1, :string, "handle", :int64, 0, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 1, :string, chunks[0])
      channel.sends_packet(FXP_READ, :long, 2, :string, "handle", :int64, 1024, :long, 1024)
      channel.sends_packet(FXP_READ, :long, 3, :string, "handle", :int64, 2048, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 2, :string, chunks[1])
      channel.sends_packet(FXP_READ, :long, 4, :string, "handle", :int64, 3072, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 3, :string, chunks[2])
      channel.sends_packet(FXP_READ, :long, 5, :string, "handle", :int64, 4096, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 4, :string, chunks[3])
      channel.sends_packet(FXP_READ, :long, 6, :string, "handle", :int64, 5120, :long, 1024)
      channel.gets_packet(FXP_STATUS, :long, 5, :long, 1)
      channel.gets_packet(FXP_STATUS, :long, 6, :long, 1)
      expect_close(channel, 7)
    end

    io = StringIO.new
    assert_pipelined_download { sftp.download("/path/to/remote", io, :read_size => 1024, :requests => 2) }
    assert_equal text, io.string
  end

  def test_download_file_should_write_out_of_order_replies_in_order
    text = "0123456789abcdef" * 192
    chunks = (0...3).map { |n| text.byteslice(n * 1024, 1024) }

    expect_sftp_session :server_version => 3 do |channel|
      expect_open(channel)
      channel.sends_packet(FXP_READ, :long, 1, :string, "handle", :int64, 0, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 1, :string, chunks[0])
      channel.sends_packet(FXP_READ, :long, 2, :string, "handle", :int64, 1024, :long, 1024)
      channel.sends_packet(FXP_READ, :long, 3, :string, "handle", :int64, 2048, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 3, :string, chunks[2])
      channel.sends_packet(FXP_READ, :long, 4, :string, "handle", :int64, 3072, :long, 1024)
      channel.sends_packet(FXP_READ, :long, 5, :string, "handle", :int64, 4096, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 2, :string, chunks[1])
      channel.sends_packet(FXP_READ, :long, 6, :string, "handle", :int64, 5120, :long, 1024)
      channel.gets_packet(FXP_STATUS, :long, 4, :long, 1)
      channel.gets_packet(FXP_STATUS, :long, 5, :long, 1)
      channel.gets_packet(FXP_STATUS, :long, 6, :long, 1)
      expect_close(channel, 7)
    end

    sink = WriteOnlySink.new
    assert_pipelined_download do
      sftp.download("/path/to/remote", sink, :read_size => 1024, :requests => 3) do |*args|
        record_progress(args)
      end
    end

    assert_equal text, sink.data
    assert_progress_reported_open :remote => "/path/to/remote"
    assert_progress_reported_get     0, chunks[0]
    assert_progress_reported_get  1024, chunks[1]
    assert_progress_reported_get  2048, chunks[2]
    assert_progress_reported_close
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_download_file_should_rerequest_the_rest_of_a_short_read
    text = "0123456789abcdef" * 128

    expect_sftp_session :server_version => 3 do |channel|
      expect_open(channel)
      channel.sends_packet(FXP_READ, :long, 1, :string, "handle", :int64, 0, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 1, :string, text.byteslice(0, 1000))
      channel.sends_packet(FXP_READ, :long, 2, :string, "handle", :int64, 1000, :long, 24)
      channel.sends_packet(FXP_READ, :long, 3, :string, "handle", :int64, 1024, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 3, :string, text.byteslice(1024, 1024))
      channel.sends_packet(FXP_READ, :long, 4, :string, "handle", :int64, 2048, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 2, :string, text.byteslice(1000, 24))
      channel.sends_packet(FXP_READ, :long, 5, :string, "handle", :int64, 3072, :long, 1024)
      channel.gets_packet(FXP_STATUS, :long, 4, :long, 1)
      channel.gets_packet(FXP_STATUS, :long, 5, :long, 1)
      expect_close(channel, 6)
    end

    io = StringIO.new
    assert_pipelined_download { sftp.download("/path/to/remote", io, :read_size => 1024, :requests => 2) }
    assert_equal text, io.string
  end

  def test_download_file_should_fail_when_data_follows_eof
    expect_sftp_session :server_version => 3 do |channel|
      expect_open(channel)
      channel.sends_packet(FXP_READ, :long, 1, :string, "handle", :int64, 0, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 1, :string, "x" * 1024)
      channel.sends_packet(FXP_READ, :long, 2, :string, "handle", :int64, 1024, :long, 1024)
      channel.sends_packet(FXP_READ, :long, 3, :string, "handle", :int64, 2048, :long, 1024)
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 1)
      channel.gets_packet(FXP_DATA, :long, 3, :string, "y" * 1024)
    end

    e = assert_raises(Net::SFTP::Exception) do
      assert_pipelined_download { sftp.download("/path/to/remote", StringIO.new, :read_size => 1024, :requests => 2) }
    end
    assert_match(/EOF at 1024/, e.message)
  end

  UNSAFE_NAMES = {
    "parent_relative" => "../x",
    "grandparent" => "../..",
    "nested" => "a/b",
    "absolute" => "/abs",
    "empty" => "",
    "nul" => "a\0b"
  }

  UNSAFE_NAMES.each do |label, name|
    define_method("test_download_directory_should_reject_#{label}_name_from_server") do
      assert_rejects_readdir_name(name)
    end
  end

  def test_download_directory_should_refuse_to_follow_symlink_at_server_named_file
    skip "File::NOFOLLOW not supported" unless defined?(File::NOFOLLOW)
    with_tmpdir do |tmp|
      Dir.mkdir("#{tmp}/local")
      File.write("#{tmp}/victim", "original")
      File.symlink("#{tmp}/victim", "#{tmp}/local/file1")

      expect_sftp_session :server_version => 3 do |channel|
        expect_readdir(channel, "/path/to/remote", "file1" => 0100644)
        channel.sends_packet(FXP_OPEN, :long, 2, :string, "/path/to/remote/file1", :long, 0x01, :long, 0)
        channel.sends_packet(FXP_READDIR, :long, 3, :string, "dir1")
        channel.gets_packet(FXP_HANDLE, :long, 2, :string, "file1")
      end

      e = assert_raises(Net::SFTP::Exception) do
        assert_scripted_command { sftp.download("/path/to/remote", "#{tmp}/local", :recursive => true) }
      end
      assert_match(/symlink/, e.message)
      assert_equal "original", File.read("#{tmp}/victim")
    end
  end

  def test_download_directory_should_refuse_to_descend_into_symlinked_directory
    with_tmpdir do |tmp|
      Dir.mkdir("#{tmp}/local")
      Dir.mkdir("#{tmp}/outside")
      File.symlink("#{tmp}/outside", "#{tmp}/local/subdir1")

      expect_sftp_session :server_version => 3 do |channel|
        expect_readdir(channel, "/path/to/remote", "subdir1" => 040755)
      end

      e = assert_raises(Net::SFTP::Exception) do
        assert_scripted_command { sftp.download("/path/to/remote", "#{tmp}/local", :recursive => true) }
      end
      assert_match(/symlink/, e.message)
      assert_equal [], Dir.children("#{tmp}/outside")
    end
  end

  def test_download_file_to_symlink_given_by_caller_should_write_through_it
    with_tmpdir do |tmp|
      File.write("#{tmp}/target", "")
      File.symlink("#{tmp}/target", "#{tmp}/link")
      text = "this is some text\n"

      expect_file_transfer("/path/to/remote", text)

      assert_scripted_command { sftp.download("/path/to/remote", "#{tmp}/link") }
      assert_equal text, File.read("#{tmp}/target")
    end
  end

  def test_download_directory_to_symlink_given_by_caller_should_write_through_it
    with_tmpdir do |tmp|
      Dir.mkdir("#{tmp}/target")
      File.symlink("#{tmp}/target", "#{tmp}/link")
      text = "contents of file1"

      expect_sftp_session :server_version => 3 do |channel|
        expect_readdir(channel, "/path/to/remote", "file1" => 0100644)
        channel.sends_packet(FXP_OPEN, :long, 2, :string, "/path/to/remote/file1", :long, 0x01, :long, 0)
        channel.sends_packet(FXP_READDIR, :long, 3, :string, "dir1")
        channel.gets_packet(FXP_HANDLE, :long, 2, :string, "file1")
        channel.sends_packet(FXP_READ, :long, 4, :string, "file1", :int64, 0, :long, 32_000)
        channel.gets_packet(FXP_STATUS, :long, 3, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, 5, :string, "dir1")
        channel.gets_packet(FXP_DATA, :long, 4, :string, text)
        channel.sends_packet(FXP_READ, :long, 6, :string, "file1", :int64, text.bytesize, :long, 32_000 - text.bytesize)
        channel.gets_packet(FXP_STATUS, :long, 5, :long, 0)
        channel.gets_packet(FXP_STATUS, :long, 6, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, 7, :string, "file1")
        channel.gets_packet(FXP_STATUS, :long, 7, :long, 0)
      end

      assert_scripted_command { sftp.download("/path/to/remote", "#{tmp}/link", :recursive => true) }
      assert_equal text, File.read("#{tmp}/target/file1")
    end
  end

  private

    class WriteOnlySink
      attr_reader :data

      def initialize
        @data = +""
      end

      def write(chunk)
        @data << chunk
        chunk.bytesize
      end

      def close; end
    end

    # A client that stops issuing reads early would otherwise wait on the
    # script forever instead of failing.
    def assert_pipelined_download(&block)
      Timeout.timeout(10) { assert_scripted_command(&block) }
    end

    def expect_open(channel)
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x01, :long, 0)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
    end

    def expect_close(channel, id)
      channel.sends_packet(FXP_CLOSE, :long, id, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, id, :long, 0)
    end

    def nofollow
      defined?(File::NOFOLLOW) ? [{ :flags => File::NOFOLLOW }] : []
    end

    def with_tmpdir
      Dir.mktmpdir("net-sftp-test") { |tmp| yield File.realpath(tmp) }
    end

    def expect_readdir(channel, remote, entries)
      channel.sends_packet(FXP_OPENDIR, :long, 0, :string, remote)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "dir1")
      channel.sends_packet(FXP_READDIR, :long, 1, :string, "dir1")
      names = entries.flat_map do |name, mode|
        [:string, name, :string, "#{name} longname", :long, 0x04, :long, mode]
      end
      channel.gets_packet(FXP_NAME, :long, 1, :long, entries.size, *names)
    end

    def assert_rejects_readdir_name(name)
      expect_sftp_session :server_version => 3 do |channel|
        channel.sends_packet(FXP_OPENDIR, :long, 0, :string, "/path/to/remote")
        channel.gets_packet(FXP_HANDLE, :long, 0, :string, "dir1")
        channel.sends_packet(FXP_READDIR, :long, 1, :string, "dir1")
        channel.gets_packet(FXP_NAME, :long, 1, :long, 3,
          :string, "..",  :string, "drwxr-xr-x  4 bob bob  136 Aug  1 ..", :long, 0x04, :long, 040755,
          :string, ".",   :string, "drwxr-xr-x  4 bob bob  136 Aug  1 .", :long, 0x04, :long, 040755,
          :string, name,  :string, "-rw-rw-r--  1 bob bob  100 Aug  1 #{name}", :long, 0x04, :long, 0100644)
      end

      File.expects(:directory?).with("/path/to/local").returns(true)
      Dir.expects(:mkdir).never
      File.expects(:open).never

      e = assert_raises(Net::SFTP::Exception) do
        assert_scripted_command { sftp.download("/path/to/remote", "/path/to/local", :recursive => true) }
      end
      assert_match(/invalid file name/, e.message)
    end

    def expect_file_transfer(remote, text, opts={})
      expect_sftp_session :server_version => 3 do |channel|
        channel.sends_packet(FXP_OPEN, :long, 0, :string, remote, :long, 0x01, :long, 0)
        channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
        channel.sends_packet(FXP_READ, :long, 1, :string, "handle", :int64, 0, :long, 32_000)
        channel.gets_packet_in_two(opts[:fragment_len], FXP_DATA, :long, 1, :string, text)
        channel.sends_packet(FXP_READ, :long, 2, :string, "handle", :int64, text.bytesize, :long, 32_000 - text.bytesize)
        channel.sends_packet(FXP_READ, :long, 3, :string, "handle", :int64, 32_000, :long, 32_000)
        channel.gets_packet(FXP_STATUS, :long, 2, :long, 1)
        channel.gets_packet(FXP_STATUS, :long, 3, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, 4, :string, "handle")
        channel.gets_packet(FXP_STATUS, :long, 4, :long, 0)
      end
    end

    # Scripts a download with one read in flight from a server that never
    # returns more than FXP_DATA_CHUNK_SIZE bytes per read.
    def prepare_large_file_download(local, remote, text, read_size = FXP_DATA_CHUNK_SIZE)
      expect_sftp_session :server_version => 3 do |channel|
        channel.sends_packet(FXP_OPEN, :long, 0, :string, remote, :long, 0x01, :long, 0)
        channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
        id = 1
        offset = 0
        length = read_size
        while offset < text.bytesize
          payload = text.byteslice(offset, [length, FXP_DATA_CHUNK_SIZE].min)
          channel.sends_packet(FXP_READ, :long, id, :string, "handle", :int64, offset, :long, length)
          channel.gets_packet(FXP_DATA, :long, id, :string, payload)
          offset += payload.bytesize
          length = payload.bytesize < length ? length - payload.bytesize : read_size
          id += 1
        end
        channel.sends_packet(FXP_READ, :long, id, :string, "handle", :int64, offset, :long, length)
        channel.gets_packet(FXP_STATUS, :long, id, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, id + 1, :string, "handle")
        channel.gets_packet(FXP_STATUS, :long, id + 1, :long, 0)
      end

      file = StringIO.new
      File.stubs(:open).with(local, "wb").returns(file)

      return file
    end

    # 0:OPENDIR(remote) ->
    # <- 0:HANDLE("dir1")
    # 1:READDIR("dir1") ->
    # <- 1:NAME("..", ".", "subdir1", "file1")
    # 2:OPENDIR(remote/subdir1) ->
    # 3:OPEN(remote/file1) ->
    # 4:READDIR("dir1") ->
    # <- 2:HANDLE("dir2")
    # 5:READDIR("dir2") ->
    # <- 3:HANDLE("file1")
    # 6:READ("file1", 0, 32k) ->
    # <- 4:STATUS(1)
    # 7:CLOSE("dir1") ->
    # <- 5:NAME("..", ".", "file2")
    # 8:OPEN(remote/subdir1/file2) ->
    # 9:READDIR("dir2") ->
    # <- 6:DATA("blah blah blah")
    # 10:READ("file1", n, 32k)
    # <- 7:STATUS(0)
    # <- 8:HANDLE("file2")
    # 11:READ("file2", 0, 32k) ->
    # <- 9:STATUS(1)
    # 12:CLOSE("dir2") ->
    # <- 10:STATUS(1)
    # 13:CLOSE("file1") ->
    # <- 11:DATA("blah blah blah")
    # 14:READ("file2", n, 32k) ->
    # <- 12:STATUS(0)
    # <- 13:STATUS(0)
    # <- 14:STATUS(1)
    # 15:CLOSE("file2") ->
    # <- 15:STATUS(0)

    def prepare_directory_tree_download(local, remote)
      file1_contents = "contents of file1"
      file2_contents = "contents of file2"
      expect_sftp_session :server_version => 3 do |channel|
        channel.sends_packet(FXP_OPENDIR, :long, 0, :string, remote)
        channel.gets_packet(FXP_HANDLE, :long, 0, :string, "dir1")

        channel.sends_packet(FXP_READDIR, :long, 1, :string, "dir1")
        channel.gets_packet(FXP_NAME, :long, 1, :long, 4,
          :string, "..",      :string, "drwxr-xr-x  4 bob bob  136 Aug  1 ..", :long, 0x04, :long, 040755,
          :string, ".",       :string, "drwxr-xr-x  4 bob bob  136 Aug  1 .", :long, 0x04, :long, 040755,
          :string, "subdir1", :string, "drwxr-xr-x  4 bob bob  136 Aug  1 subdir1", :long, 0x04, :long, 040755,
          :string, "file1",   :string, "-rw-rw-r--  1 bob bob  100 Aug  1 file1", :long, 0x04, :long, 0100644)

        channel.sends_packet(FXP_OPENDIR, :long, 2, :string, File.join(remote, "subdir1"))
        channel.sends_packet(FXP_OPEN, :long, 3, :string, File.join(remote, "file1"), :long, 0x01, :long, 0)
        channel.sends_packet(FXP_READDIR, :long, 4, :string, "dir1")

        channel.gets_packet(FXP_HANDLE, :long, 2, :string, "dir2")
        channel.sends_packet(FXP_READDIR, :long, 5, :string, "dir2")

        channel.gets_packet(FXP_HANDLE, :long, 3, :string, "file1")
        channel.sends_packet(FXP_READ, :long, 6, :string, "file1", :int64, 0, :long, 32_000)

        channel.gets_packet(FXP_STATUS, :long, 4, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, 7, :string, "dir1")

        channel.gets_packet(FXP_NAME, :long, 5, :long, 3,
          :string, "..",    :string, "drwxr-xr-x  4 bob bob  136 Aug  1 ..", :long, 0x04, :long, 040755,
          :string, ".",     :string, "drwxr-xr-x  4 bob bob  136 Aug  1 .", :long, 0x04, :long, 040755,
          :string, "file2", :string, "-rw-rw-r--  1 bob bob  100 Aug  1 file2", :long, 0x04, :long, 0100644)

        channel.sends_packet(FXP_OPEN, :long, 8, :string, File.join(remote, "subdir1", "file2"), :long, 0x01, :long, 0)
        channel.sends_packet(FXP_READDIR, :long, 9, :string, "dir2")

        channel.gets_packet(FXP_DATA, :long, 6, :string, file1_contents)
        channel.sends_packet(FXP_READ, :long, 10, :string, "file1", :int64, file1_contents.bytesize, :long, 32_000 - file1_contents.bytesize)

        channel.gets_packet(FXP_STATUS, :long, 7, :long, 0)
        channel.gets_packet(FXP_HANDLE, :long, 8, :string, "file2")
        channel.sends_packet(FXP_READ, :long, 11, :string, "file2", :int64, 0, :long, 32_000)

        channel.gets_packet(FXP_STATUS, :long, 9, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, 12, :string, "dir2")

        channel.gets_packet(FXP_STATUS, :long, 10, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, 13, :string, "file1")

        channel.gets_packet(FXP_DATA, :long, 11, :string, file2_contents)
        channel.sends_packet(FXP_READ, :long, 14, :string, "file2", :int64, file2_contents.bytesize, :long, 32_000 - file2_contents.bytesize)

        channel.gets_packet(FXP_STATUS, :long, 12, :long, 0)
        channel.gets_packet(FXP_STATUS, :long, 13, :long, 0)
        channel.gets_packet(FXP_STATUS, :long, 14, :long, 1)
        channel.sends_packet(FXP_CLOSE, :long, 15, :string, "file2")
        channel.gets_packet(FXP_STATUS, :long, 15, :long, 0)
      end

      File.expects(:directory?).with(local).returns(false)
      File.expects(:directory?).with(File.join(local, "subdir1")).returns(false)
      Dir.expects(:mkdir).with(local)
      Dir.expects(:mkdir).with(File.join(local, "subdir1"))

      file1 = StringIO.new
      file2 = StringIO.new
      File.expects(:open).with(File.join(local, "file1"), "wb", *nofollow).returns(file1)
      File.expects(:open).with(File.join(local, "subdir1", "file2"), "wb", *nofollow).returns(file2)

      [file1, file2]
    end
end
