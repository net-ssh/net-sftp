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

    assert_command_with_callback(:open, "/path/to/file") do |response|
      assert !response.ok?
      assert_equal 2, response.code
    end
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

  def test_v4_open_with_permissions_should_specify_permissions
    expect_open("/path/to/file", "r", 0765, :server_version => 4)
    assert_successful_open("/path/to/file", "r", :permissions => 0765)
  end

  def test_v5_open_read_only_shuld_invoke_callback
    expect_open("/path/to/file", "r", 0765, :server_version => 5)
    assert_successful_open("/path/to/file", "r", :permissions => 0765)
  end

  def test_v6_open_with_permissions_should_specify_permissions
    expect_open("/path/to/file", "r", 0765, :server_version => 6)
    assert_successful_open("/path/to/file", "r", :permissions => 0765)
  end

  def test_close_should_send_close_request_and_invoke_callback
    expect_sftp_session do |channel|
      channel.sends_packet(FXP_CLOSE, :long, 0, :string, "handle")
      channel.gets_packet(FXP_STATUS, :long, 0, :long, 0)
    end

    assert_command_with_callback(:close, "handle") { |r| assert r.ok? }
  end

  def test_read_should_send_read_request_and_invoke_callback
    expect_sftp_session do |channel|
      channel.sends_packet(FXP_READ, :long, 0, :string, "handle", :int64, 512123, :long, 1024)
      channel.gets_packet(FXP_DATA, :long, 0, :string, "this is some data!")
    end

    assert_command_with_callback(:read, "handle", 512123, 1024) do |response|
      assert response.ok?
      assert_equal "this is some data!", response[:data]
    end
  end

  def test_write_should_send_write_request_and_invoke_callback
    expect_sftp_session do |channel|
      channel.sends_packet(FXP_WRITE, :long, 0, :string, "handle", :int64, 512123, :string, "this is some data!")
      channel.gets_packet(FXP_STATUS, :long, 0, :long, 0)
    end

    assert_command_with_callback(:write, "handle", 512123, "this is some data!") do |response|
      assert response.ok?
    end
  end

  def test_v1_lstat_should_send_lstat_request_and_invoke_callback
    expect_sftp_session :server_version => 1 do |channel|
      channel.sends_packet(FXP_LSTAT, :long, 0, :string, "/path/to/file")
      channel.gets_packet(FXP_ATTRS, :long, 0, :long, 0xF, :int64, 123456, :long, 1, :long, 2, :long, 0765, :long, 123456789, :long, 234567890)
    end

    assert_command_with_callback(:lstat, "/path/to/file") do |response|
      assert response.ok?
      assert_equal 123456, response[:attrs].size
      assert_equal 1, response[:attrs].uid
      assert_equal 2, response[:attrs].gid
      assert_equal 0765, response[:attrs].permissions
      assert_equal 123456789, response[:attrs].atime
      assert_equal 234567890, response[:attrs].mtime
    end
  end

  def test_v4_lstat_should_send_default_flags_parameter
    expect_sftp_session :server_version => 4 do |channel|
      channel.sends_packet(FXP_LSTAT, :long, 0, :string, "/path/to/file", :long, 0x800001fd)
      channel.gets_packet(FXP_STATUS, :long, 0, :long, 2)
    end

    assert_command_with_callback(:lstat, "/path/to/file")
  end

  def test_v4_lstat_should_honor_flags_parameter
    expect_sftp_session :server_version => 4 do |channel|
      channel.sends_packet(FXP_LSTAT, :long, 0, :string, "/path/to/file", :long, 0x1)
      channel.gets_packet(FXP_STATUS, :long, 0, :long, 2)
    end

    assert_command_with_callback(:lstat, "/path/to/file", 0x1)
  end

  private

    class V1 < Net::SFTP::Protocol::V01::Base
    end

    class V5 < Net::SFTP::Protocol::V05::Base
    end

    def assert_scripted_command
      assert_scripted do
        sftp.open
        yield
        sftp.loop
      end
    end

    def assert_command_with_callback(command, *args)
      called = false
      assert_scripted_command do
        sftp.base.send(command, *args) do |response|
          called = true
          yield response if block_given?
        end
      end
      assert called, "expected callback to be invoked, but it wasn't"
    end

    def assert_successful_open(*args)
      assert_command_with_callback(:open, *args) do |response|
        assert response.ok?
        assert_equal "handle", response[:handle]
      end
    end

    def expect_open(path, mode, perms, options={})
      version = options[:server_version] || 6

      fail = options.delete(:fail)

      attrs = [:long, perms ? 0x4 : 0]
      attrs += [:byte, 1] if version >= 4
      attrs += [:long, perms] if perms

      expect_sftp_session(options) do |channel|
        if version >= 5
          flags, access = case mode
            when "r" then 
              [V5::F_OPEN_EXISTING, V5::ACE::F_READ_DATA | V5::ACE::F_READ_ATTRIBUTES]
            when "w" then
              [V5::F_CREATE_TRUNCATE, V5::ACE::F_WRITE_DATA | V5::ACE::F_WRITE_ATTRIBUTES]
            when "rw" then
              [V5::F_OPEN_OR_CREATE, V5::ACE::F_READ_DATA | V5::ACE::F_READ_ATTRIBUTES | V5::ACE::F_WRITE_DATA | V5::ACE::F_WRITE_ATTRIBUTES]
            when "a" then
              [V5::F_OPEN_OR_CREATE | V5::F_APPEND_DATA, V5::ACE::F_WRITE_DATA | V5::ACE::F_WRITE_ATTRIBUTES | V5::ACE::F_APPEND_DATA]
            else raise ArgumentError, "unsupported mode #{mode.inspect}"
          end

          channel.sends_packet(FXP_OPEN, :long, 0, :string, path, :long, access, :long, flags, *attrs)
        else
          flags = case mode
            when "r"  then V1::F_READ
            when "w"  then V1::F_WRITE | V1::F_TRUNC | V1::F_CREAT
            when "rw" then V1::F_WRITE | V1::F_READ
            when "a"  then V1::F_APPEND | V1::F_CREAT
            else raise ArgumentError, "unsupported mode #{mode.inspect}"
          end

          channel.sends_packet(FXP_OPEN, :long, 0, :string, path, :long, flags, *attrs)
        end

        if fail
          channel.gets_packet(FXP_STATUS, :long, 0, :long, fail)
        else
          channel.gets_packet(FXP_HANDLE, :long, 0, :string, "handle")
        end
      end
    end
end