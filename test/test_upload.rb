require "common"

class UploadTest < Net::SFTP::TestCase
  def setup
    prepare_progress!
  end

  def test_upload_file_should_send_file_contents
    expect_file_transfer("/path/to/local", "/path/to/remote", "here are the contents")
    assert_scripted_command { sftp.upload("/path/to/local", "/path/to/remote") }
  end

  def test_upload_file_should_close_the_local_file_it_opened
    file = expect_file_transfer("/path/to/local", "/path/to/remote", "here are the contents")

    assert_scripted_command { sftp.upload("/path/to/local", "/path/to/remote") }
    assert file.closed?
  end

  def test_upload_file_should_handle_Pathname
    local = Pathname.new("/path/to/local").freeze
    remote = Pathname.new("/path/to/remote").freeze
    expect_file_transfer(local.to_s, remote.to_s, "here are the contents")
    assert_scripted_command { sftp.upload(local, remote) }
  end

  def test_upload_file_without_remote_uses_filename_of_local_file
    expect_file_transfer("/path/to/local", "local", "here are the contents")

    assert_scripted_command do
      sftp.upload("/path/to/local") { |*args| record_progress(args) }
    end

    assert_progress_reported_open(:remote => "local")
    assert_progress_reported_put(0, "here are the contents", :remote => "local")
    assert_progress_reported_close(:remote => "local")
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_upload_file_with_progress_should_report_progress
    expect_file_transfer("/path/to/local", "/path/to/remote", "here are the contents")

    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote") { |*args| record_progress(args) }
    end

    assert_progress_reported_open(:remote => "/path/to/remote")
    assert_progress_reported_put(0, "here are the contents", :remote => "/path/to/remote")
    assert_progress_reported_close(:remote => "/path/to/remote")
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_upload_file_with_progress_handler_should_report_progress
    expect_file_transfer("/path/to/local", "/path/to/remote", "here are the contents")

    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote", :progress => ProgressHandler.new(@progress))
    end

    assert_progress_reported_open(:remote => "/path/to/remote")
    assert_progress_reported_put(0, "here are the contents", :remote => "/path/to/remote")
    assert_progress_reported_close(:remote => "/path/to/remote")
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_upload_file_should_read_chunks_of_size(requested_size=nil)
    size = requested_size || Net::SFTP::Operations::Upload::DEFAULT_READ_SIZE
    expect_sftp_session :server_version => 3 do |channel|
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x1A, :long, 0x04, :long, 0644)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
      channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, "a" * size)
      channel.sends_packet(FXP_WRITE, :long, 2, :string, "handle", :int64, size, :string, "b" * size)
      channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
      channel.sends_packet(FXP_WRITE, :long, 3, :string, "handle", :int64, size*2, :string, "c" * size)
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      channel.sends_packet(FXP_WRITE, :long, 4, :string, "handle", :int64, size*3, :string, "d" * size)
      channel.gets_packet(FXP_STATUS, :long, 3, :long, 0)
      channel.sends_packet(FXP_CLOSE, :long, 5, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 4, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 5, :long, 0)
    end

    expect_file("/path/to/local", "a" * size + "b" * size + "c" * size + "d" * size)

    assert_scripted_command do
      opts = {}
      opts[:read_size] = size if requested_size
      sftp.upload("/path/to/local", "/path/to/remote", opts)
    end
  end

  def test_upload_file_with_custom_read_size_should_read_chunks_of_that_size
    test_upload_file_should_read_chunks_of_size(100)
  end

  def test_upload_file_with_custom_requests_should_start_that_many_writes
    size = Net::SFTP::Operations::Upload::DEFAULT_READ_SIZE
    expect_sftp_session :server_version => 3 do |channel|
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x1A, :long, 0x04, :long, 0644)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
      channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, "a" * size)
      channel.sends_packet(FXP_WRITE, :long, 2, :string, "handle", :int64, size, :string, "b" * size)
      channel.sends_packet(FXP_WRITE, :long, 3, :string, "handle", :int64, size*2, :string, "c" * size)
      channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
      channel.sends_packet(FXP_WRITE, :long, 4, :string, "handle", :int64, size*3, :string, "d" * size)
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      channel.sends_packet(FXP_CLOSE, :long, 5, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 3, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 4, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 5, :long, 0)
    end

    expect_file("/path/to/local", "a" * size + "b" * size + "c" * size + "d" * size)

    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote", :requests => 3)
    end
  end

  def test_abort_should_stop_writing_and_close_the_file
    size = Net::SFTP::Operations::Upload::DEFAULT_READ_SIZE
    expect_sftp_session :server_version => 3 do |channel|
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x1A, :long, 0x04, :long, 0644)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
      channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, "a" * size)
      channel.sends_packet(FXP_WRITE, :long, 2, :string, "handle", :int64, size, :string, "b" * size)
      channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
      channel.sends_packet(FXP_CLOSE, :long, 3, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 3, :long, 0)
    end

    file = expect_file("/path/to/local", "a" * size + "b" * size + "c" * size + "d" * size)

    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote", :requests => 2) do |*args|
        record_progress(args)
        args[1].abort! if args[0] == :put && args[3] == size
      end
    end

    assert file.closed?
    assert_progress_reported_open(:remote => "/path/to/remote")
    assert_progress_reported_put(0, "a" * size, :remote => "/path/to/remote")
    assert_progress_reported_put(size, "b" * size, :remote => "/path/to/remote")
    assert_progress_reported_close(:remote => "/path/to/remote")
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_upload_directory_should_mirror_directory_structure_remotely
    prepare_directory

    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote", :mkdir => true)
    end
  end

  def test_upload_directory_with_handler_should_report_progress
    prepare_directory

    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote", :mkdir => true) { |*args| record_progress(args) }
    end

    assert_progress_reported_open(:remote => "/path/to/remote/file1")
    assert_progress_reported_open(:remote => "/path/to/remote/file2")
    assert_progress_reported_open(:remote => "/path/to/remote/file3")
    assert_progress_reported_mkdir("/path/to/remote/subdir")
    assert_progress_reported_open(:remote => "/path/to/remote/subdir/other1")
    assert_progress_reported_open(:remote => "/path/to/remote/subdir/other2")
    assert_progress_reported_put(0, "contents of file1", :remote => "/path/to/remote/file1")
    assert_progress_reported_put(0, "contents of file2", :remote => "/path/to/remote/file2")
    assert_progress_reported_put(0, "contents of file3", :remote => "/path/to/remote/file3")
    assert_progress_reported_close(:remote => "/path/to/remote/file1")
    assert_progress_reported_put(0, "contents of other1", :remote => "/path/to/remote/subdir/other1")
    assert_progress_reported_put(0, "contents of other2", :remote => "/path/to/remote/subdir/other2")
    assert_progress_reported_close(:remote => "/path/to/remote/file2")
    assert_progress_reported_close(:remote => "/path/to/remote/file3")
    assert_progress_reported_close(:remote => "/path/to/remote/subdir/other1")
    assert_progress_reported_close(:remote => "/path/to/remote/subdir/other2")
    assert_progress_reported_finish
    assert_no_more_reported_events
  end

  def test_upload_io_should_send_io_as_file
    expect_sftp_session :server_version => 3 do |channel|
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x1A, :long, 0)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
      channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, "this is some text")
      channel.sends_packet(FXP_CLOSE, :long, 2, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
    end

    source = StringIO.new("this is some text")
    assert_scripted_command { sftp.upload(source, "/path/to/remote") }
    assert !source.closed?
  end

  def test_upload_file_should_not_send_setuid_setgid_or_sticky_bits
    expect_file_transfer("/path/to/local", "/path/to/remote", "here are the contents", 0755)
    File.stubs(:open).with("/path/to/local", "rb").returns(local_file("here are the contents", 0107755))
    assert_scripted_command { sftp.upload("/path/to/local", "/path/to/remote") }
  end

  def test_upload_file_with_preserve_should_send_times_and_set_attributes_before_close
    expect_file("/path/to/local", "here are the contents")
    expect_sftp_session :server_version => 3 do |channel|
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x1A, :long, 0x0C, :long, 0644, :long, 1, :long, 2)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
      channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, "here are the contents")
      channel.sends_packet(FXP_FSETSTAT, :long, 2, :string, "handle", :long, 0x0C, :long, 0644, :long, 1, :long, 2)
      channel.sends_packet(FXP_CLOSE, :long, 3, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 3, :long, 0)
    end

    assert_scripted_command { sftp.upload("/path/to/local", "/path/to/remote", :preserve => true) }
  end

  def test_upload_file_with_preserve_should_warn_when_fsetstat_fails
    expect_file("/path/to/local", "here are the contents")
    expect_sftp_session :server_version => 3 do |channel|
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x1A, :long, 0x0C, :long, 0644, :long, 1, :long, 2)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
      channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, "here are the contents")
      channel.sends_packet(FXP_FSETSTAT, :long, 2, :string, "handle", :long, 0x0C, :long, 0644, :long, 1, :long, 2)
      channel.sends_packet(FXP_CLOSE, :long, 3, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 3)
      channel.gets_packet(FXP_STATUS, :long, 3, :long, 0)
    end
    log = StringIO.new

    assert_scripted_command { log_warnings_to(log); sftp.upload("/path/to/local", "/path/to/remote", :preserve => true) }
    assert_match(%r{fsetstat /path/to/remote failed: permission denied}, log.string)
  end

  def test_upload_directory_should_warn_when_setstat_fails
    expect_directory("/path/to/local", %w(. .. file1), 040700)
    expect_file("/path/to/local/file1", "contents of file1")

    expect_sftp_session :server_version => 3 do |ch|
      ch.sends_packet(FXP_MKDIR, :long, 0, :string, "/path/to/remote", :long, 0x04, :long, 0700)
      ch.gets_packet(FXP_STATUS, :long, 0, :long, 0)
      ch.sends_packet(FXP_OPEN, :long, 1, :string, "/path/to/remote/file1", :long, 0x1A, :long, 0x04, :long, 0644)
      ch.gets_packet(FXP_HANDLE, :long, 1, :string, "hfile1")
      ch.sends_packet(FXP_WRITE, :long, 2, :string, "hfile1", :int64, 0, :string, "contents of file1")
      ch.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      ch.sends_packet(FXP_CLOSE, :long, 3, :string, "hfile1")
      ch.gets_packet(FXP_STATUS, :long, 3, :long, 0)
      ch.sends_packet(FXP_SETSTAT, :long, 4, :string, "/path/to/remote", :long, 0x04, :long, 0700)
      ch.gets_packet(FXP_STATUS, :long, 4, :long, 3)
    end
    log = StringIO.new

    assert_scripted_command do
      log_warnings_to(log)
      sftp.upload("/path/to/local", "/path/to/remote", :mkdir => true) { |*args| record_progress(args) }
    end
    assert_match(%r{setstat /path/to/remote failed: permission denied}, log.string)
    assert_equal :finish, @progress.last.first
  end

  def test_upload_io_with_preserve_should_not_set_attributes
    expect_sftp_session :server_version => 3 do |channel|
      channel.sends_packet(FXP_OPEN, :long, 0, :string, "/path/to/remote", :long, 0x1A, :long, 0)
      channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
      channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, "this is some text")
      channel.sends_packet(FXP_CLOSE, :long, 2, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
      channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
    end

    assert_scripted_command do
      sftp.upload(StringIO.new("this is some text"), "/path/to/remote", :preserve => true)
    end
  end

  def test_upload_directory_with_preserve_should_set_directory_times_after_its_contents
    expect_directory("/path/to/local", %w(. .. file1), 042755, Time.at(3), Time.at(4))
    expect_file("/path/to/local/file1", "contents of file1")

    expect_sftp_session :server_version => 3 do |ch|
      ch.sends_packet(FXP_MKDIR, :long, 0, :string, "/path/to/remote", :long, 0x04, :long, 0755)
      ch.gets_packet(FXP_STATUS, :long, 0, :long, 0)
      ch.sends_packet(FXP_OPEN, :long, 1, :string, "/path/to/remote/file1", :long, 0x1A, :long, 0x0C, :long, 0644, :long, 1, :long, 2)
      ch.gets_packet(FXP_HANDLE, :long, 1, :string, "hfile1")
      ch.sends_packet(FXP_WRITE, :long, 2, :string, "hfile1", :int64, 0, :string, "contents of file1")
      ch.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      ch.sends_packet(FXP_FSETSTAT, :long, 3, :string, "hfile1", :long, 0x0C, :long, 0644, :long, 1, :long, 2)
      ch.sends_packet(FXP_CLOSE, :long, 4, :string, "hfile1")
      ch.gets_packet(FXP_STATUS, :long, 3, :long, 0)
      ch.gets_packet(FXP_STATUS, :long, 4, :long, 0)
      ch.sends_packet(FXP_SETSTAT, :long, 5, :string, "/path/to/remote", :long, 0x0C, :long, 0755, :long, 3, :long, 4)
      ch.gets_packet(FXP_STATUS, :long, 5, :long, 0)
    end

    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote", :mkdir => true, :preserve => true)
    end
  end

  def test_upload_should_reject_nonpositive_requests_and_read_size
    session = stub("sftp", :logger => nil)

    [{ :requests => 0 }, { :requests => -1 }, { :requests => "many" },
     { :read_size => 0 }, { :read_size => -1 }].each do |opts|
      assert_raises(ArgumentError, opts.inspect) do
        Net::SFTP::Operations::Upload.new(session, StringIO.new, "/path/to/remote", opts)
      end
    end
  end

  def test_upload_with_nil_requests_and_read_size_should_use_defaults
    expect_file_transfer("/path/to/local", "/path/to/remote", "here are the contents")
    assert_scripted_command do
      sftp.upload("/path/to/local", "/path/to/remote", :requests => nil, :read_size => nil)
    end
  end

  private

    def prepare_directory
      expect_directory("/path/to/local", %w(. .. file1 file2 file3 subdir))
      expect_directory("/path/to/local/subdir", %w(. .. other1 other2), 040500)
      expect_file("/path/to/local/file1", "contents of file1")
      expect_file("/path/to/local/file2", "contents of file2")
      expect_file("/path/to/local/file3", "contents of file3")
      expect_file("/path/to/local/subdir/other1", "contents of other1")
      expect_file("/path/to/local/subdir/other2", "contents of other2")

      expect_sftp_session :server_version => 3 do |ch|
        ch.sends_packet(FXP_MKDIR, :long, 0, :string, "/path/to/remote", :long, 0x04, :long, 0755)
        ch.gets_packet(FXP_STATUS, :long, 0, :long, 0)
        ch.sends_packet(FXP_OPEN, :long, 1, :string, "/path/to/remote/file1", :long, 0x1A, :long, 0x04, :long, 0644)
        ch.sends_packet(FXP_OPEN, :long, 2, :string, "/path/to/remote/file2", :long, 0x1A, :long, 0x04, :long, 0644)
        ch.sends_packet(FXP_OPEN, :long, 3, :string, "/path/to/remote/file3", :long, 0x1A, :long, 0x04, :long, 0644)
        ch.sends_packet(FXP_MKDIR, :long, 4, :string, "/path/to/remote/subdir", :long, 0x04, :long, 0700)
        ch.sends_packet(FXP_OPEN, :long, 5, :string, "/path/to/remote/subdir/other1", :long, 0x1A, :long, 0x04, :long, 0644)
        ch.sends_packet(FXP_OPEN, :long, 6, :string, "/path/to/remote/subdir/other2", :long, 0x1A, :long, 0x04, :long, 0644)
        ch.gets_packet(FXP_HANDLE, :long, 1, :string, "hfile1")
        ch.sends_packet(FXP_WRITE, :long, 7, :string, "hfile1", :int64, 0, :string, "contents of file1")
        ch.gets_packet(FXP_HANDLE, :long, 2, :string, "hfile2")
        ch.sends_packet(FXP_WRITE, :long, 8, :string, "hfile2", :int64, 0, :string, "contents of file2")
        ch.gets_packet(FXP_HANDLE, :long, 3, :string, "hfile3")
        ch.sends_packet(FXP_WRITE, :long, 9, :string, "hfile3", :int64, 0, :string, "contents of file3")
        ch.gets_packet(FXP_STATUS, :long, 4, :long, 0)
        ch.gets_packet(FXP_HANDLE, :long, 5, :string, "hother1")
        ch.sends_packet(FXP_CLOSE, :long, 10, :string, "hfile1")
        ch.sends_packet(FXP_WRITE, :long, 11, :string, "hother1", :int64, 0, :string, "contents of other1")
        ch.gets_packet(FXP_HANDLE, :long, 6, :string, "hother2")
        ch.sends_packet(FXP_WRITE, :long, 12, :string, "hother2", :int64, 0, :string, "contents of other2")
        ch.gets_packet(FXP_STATUS, :long, 7, :long, 0)
        ch.sends_packet(FXP_CLOSE, :long, 13, :string, "hfile2")
        ch.gets_packet(FXP_STATUS, :long, 8, :long, 0)
        ch.sends_packet(FXP_CLOSE, :long, 14, :string, "hfile3")
        ch.gets_packet(FXP_STATUS, :long, 9, :long, 0)
        ch.sends_packet(FXP_CLOSE, :long, 15, :string, "hother1")
        ch.gets_packet(FXP_STATUS, :long, 10, :long, 0)
        ch.sends_packet(FXP_CLOSE, :long, 16, :string, "hother2")
        ch.gets_packet(FXP_STATUS, :long, 11, :long, 0)
        ch.gets_packet(FXP_STATUS, :long, 12, :long, 0)
        ch.gets_packet(FXP_STATUS, :long, 13, :long, 0)
        ch.gets_packet(FXP_STATUS, :long, 14, :long, 0)
        ch.gets_packet(FXP_STATUS, :long, 15, :long, 0)
        ch.gets_packet(FXP_STATUS, :long, 16, :long, 0)
        ch.sends_packet(FXP_SETSTAT, :long, 17, :string, "/path/to/remote/subdir", :long, 0x04, :long, 0500)
        ch.sends_packet(FXP_SETSTAT, :long, 18, :string, "/path/to/remote", :long, 0x04, :long, 0755)
        ch.gets_packet(FXP_STATUS, :long, 17, :long, 0)
        ch.gets_packet(FXP_STATUS, :long, 18, :long, 0)
      end
    end

    def expect_file(path, data)
      File.stubs(:directory?).with(path).returns(false)
      File.stubs(:exist?).with(path).returns(true)
      file = local_file(data)
      File.stubs(:open).with(path, "rb").returns(file)
      file
    end

    def local_file(data, mode = 0100644)
      file = StringIO.new(data)
      file.stubs(:stat).returns(stub("stat", :size => data.length, :mode => mode, :atime => Time.at(1), :mtime => Time.at(2)))
      file
    end

    def expect_directory(path, entries, mode = 040755, atime = Time.at(0), mtime = Time.at(0))
      Dir.stubs(:entries).with(path).returns(entries)
      File.stubs(:directory?).with(path).returns(true)
      File.stubs(:stat).with(path).returns(stub("stat", :mode => mode, :atime => atime, :mtime => mtime))
    end

    def expect_file_transfer(local, remote, data, permissions = 0644)
      expect_sftp_session :server_version => 3 do |channel|
        channel.sends_packet(FXP_OPEN, :long, 0, :string, remote, :long, 0x1A, :long, 0x04, :long, permissions)
        channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
        channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, data)
        channel.sends_packet(FXP_CLOSE, :long, 2, :string, "handle")
        channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
        channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      end

      expect_file(local, data)
    end
end
