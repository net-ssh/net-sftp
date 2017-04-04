require 'common'
require 'protocol/06/test_base'

class Protocol::V06::TestExtended < Protocol::V06::TestBase

  def setup
    @session = stub('session', :logger => nil)
    @base = driver.new(@session)
  end

  def test_version
    assert_equal 6, @base.version
  end

  def test_md5_should_send_md5_hash_packet
    @session.expects(:send_packet).with(FXP_EXTENDED, :long, 0, :string, "md5-hash-handle", :int64, 112233, :int64, 445566, :string, "ABCDEF")
    assert_equal 0, @base.md5("test", 112233, 445566, "ABCDEF")
  end

  def test_hash_should_send_hash_packet
    @session.expects(:send_packet).with(FXP_EXTENDED, :long, 0, :string, "check-file-handle", :string, "test", :string, "md5,sha256,sha384,sha512", :int64, 112233, :int64, 445566, :long, 0)
    assert_equal 0, @base.hash("test", 112233, 445566)
  end

  def test_hash_should_send_hash_packet_with_block_size
    @session.expects(:send_packet).with(FXP_EXTENDED, :long, 0, :string, "check-file-handle", :string, "test", :string, "md5,sha256,sha384,sha512", :int64, 112233, :int64, 445566, :long, 256)
    assert_equal 0, @base.hash("test", 112233, 445566, 123)
  end

  def test_hash_should_send_hash_packet_with_valid_block_size
    @session.expects(:send_packet).with(FXP_EXTENDED, :long, 0, :string, "check-file-handle", :string, "test", :string, "md5,sha256,sha384,sha512", :int64, 112233, :int64, 445566, :long, 256)
    assert_equal 0, @base.hash("test", 112233, 445566, -1)
  end

  def test_space_available_should_send_space_available_packet
    @session.expects(:send_packet).with(FXP_EXTENDED, :long, 0, :string, "space-available", :string, "/var/log/Xorg.0.log")
    assert_equal 0, @base.space_available("/var/log/Xorg.0.log")
  end

  def test_home_should_send_home_directory_packet
    @session.expects(:send_packet).with(FXP_EXTENDED, :long, 0, :string, "home-directory", :string, "test")
    assert_equal 0, @base.home("test")
  end

  private

    def driver
      Net::SFTP::Protocol::V06::Extended
    end
end
