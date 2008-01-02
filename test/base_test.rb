require "#{File.dirname(__FILE__)}/common"

class BaseTest < Net::SFTP::TestCase
  (1..6).each do |version|
    define_method("test_server_reporting_version_#{version}_should_cause_version_#{version}_to_be_used") do
      expect_sftp_session :server_version => version
      assert_scripted { sftp.open }
      assert_equal version, sftp.base.protocol.version
    end
  end

  def test_v1_open_read_only_that_succeeds_should_invoke_callback
    expect_open("/path/to/file", "r", nil, :server_version => 1)
    assert_successful_open("/path/to/file")
  end

  def test_v1_open_read_only_that_fails_should_invoke_callback
    expect_open("/path/to/file", "r", nil, :server_version => 1, :fail => 2)
    called = false

    assert_scripted_command do
      sftp.base.open("/path/to/file") do |response|
        called = true
        assert !response.ok?
        assert_equal 2, response.code
      end
    end

    assert called, "expected callback to be invoked"
  end

  def test_v1_open_write_only_that_succeeds_should_invoke_callback
    expect_open("/path/to/file", "w", nil, :server_version => 1)
    assert_successful_open("/path/to/file", "w")
  end

  def test_v1_open_read_write_that_succeeds_should_invoke_callback
    expect_open("/path/to/file", "rw", nil, :server_version => 1)
    assert_successful_open("/path/to/file", "r+")
  end

  def test_v1_open_append_that_succeeds_should_invoke_callback
    expect_open("/path/to/file", "a", nil, :server_version => 1)
    assert_successful_open("/path/to/file", "a")
  end

  def test_v1_open_with_permissions_should_specify_permissions
    expect_open("/path/to/file", "r", 0765, :server_version => 1)
    assert_successful_open("/path/to/file", "r", :permissions => 0765)
  end

  private

    def assert_scripted_command
      assert_scripted do
        sftp.open
        yield
        sftp.loop
      end
    end

    def assert_successful_open(*args)
      called = false
      assert_scripted_command do
        sftp.base.open(*args) do |response|
          called = true
          assert response.ok?
          assert_equal "handle", response[:handle]
        end
      end
      assert called, "expected callback to be invoked"
    end

    def expect_open(path, mode, perms, options={})
      fail = options.delete(:fail)
      flags = case mode
        when "r"  then Net::SFTP::Protocol::V01::Base::F_READ
        when "w"  then Net::SFTP::Protocol::V01::Base::F_WRITE | Net::SFTP::Protocol::V01::Base::F_TRUNC | Net::SFTP::Protocol::V01::Base::F_CREAT
        when "rw" then Net::SFTP::Protocol::V01::Base::F_WRITE | Net::SFTP::Protocol::V01::Base::F_READ
        when "a"  then Net::SFTP::Protocol::V01::Base::F_APPEND | Net::SFTP::Protocol::V01::Base::F_CREAT
        else raise ArgumentError, "unsupported mode #{mode.inspect}"
      end

      if perms
        attrs = [:long, 0x4, :long, perms]
      else
        attrs = [:long, 0]
      end

      expect_sftp_session(options) do |channel|
        channel.sends_packet(FXP_OPEN, :long, 0, :string, path, :long, flags, *attrs)
        if fail
          channel.gets_packet(FXP_STATUS, :long, 0, :long, fail)
        else
          channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
        end
      end
    end
end