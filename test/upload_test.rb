require "#{File.dirname(__FILE__)}/common"

class UploadTest < Net::SFTP::TestCase
  def setup
    @progress = []
  end

  def test_upload_file_should_send_file_contents
    expect_file_transfer("/path/to/local", "/path/to/remote", "here are the contents")
    assert_scripted_command { sftp.upload("/path/to/local", "/path/to/remote") }
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

  # local as directory
  # local as directory with progress
  # local as IO with :name
  # local as IO without :name
  # local as IO with progress

  # upload with custom # of :requests
  # upload with custom :read_size

  private

    def expect_file(path, data)
      File.stubs(:directory?).with(path).returns(false)
      File.stubs(:exists?).with(path).returns(true)
      file = StringIO.new(data)
      file.stubs(:stat).returns(stub("stat", :size => data.length))
      File.stubs(:open).with(path).returns(file)
    end

    def expect_file_transfer(local, remote, data)
      expect_sftp_session :server_version => 3 do |channel|
        channel.sends_packet(FXP_OPEN, :long, 0, :string, remote, :long, 0x1A, :long, 0)
        channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
        channel.sends_packet(FXP_WRITE, :long, 1, :string, "handle", :int64, 0, :string, data)
        channel.sends_packet(FXP_CLOSE, :long, 2, :string, "handle")
        channel.gets_packet(FXP_STATUS, :long, 1, :long, 0)
        channel.gets_packet(FXP_STATUS, :long, 2, :long, 0)
      end

      expect_file(local, data)
    end

    def assert_progress_reported_open(expect={})
      assert_progress_reported(:open, expect)
    end

    def assert_progress_reported_put(offset, data, expect={})
      assert_equal offset, current_event[3] if offset
      assert_equal data, current_event[4] if data
      assert_progress_reported(:put, expect)
    end

    def assert_progress_reported_close(expect={})
      assert_progress_reported(:close, expect)
    end

    def assert_progress_reported_finish
      assert_progress_reported(:finish)
    end

    def assert_progress_reported(event, expect={})
      assert_equal event, current_event[0]
      expect.each do |key, value|
        assert_equal value, current_event[2].send(key)
      end
      next_event!
    end

    def assert_no_more_reported_events
      assert @progress.empty?, "expected #{@progress.empty?} to be empty"
    end

    def record_progress(event)
      @progress << event
    end

    def current_event
      @progress.first
    end

    def next_event!
      @progress.shift
    end
end