require 'common'

class Protocol::V01::TestBase < Net::SFTP::TestCase
  include Net::SFTP::Constants

  Base = Net::SFTP::Protocol::V01::Base

  def setup
    @session = stub('session', :logger => nil)
    @base = Net::SFTP::Protocol::V01::Base.new(@session)
  end

  def test_version_should_be_1
    assert_equal 1, @base.version
  end

  def test_parse_handle_packet_should_read_string_from_packet_and_return_handle_in_hash
    packet = Net::SSH::Buffer.from(:string, "here is a string")
    assert_equal({ :handle => "here is a string" }, @base.parse_handle_packet(packet))
  end

  def test_parse_status_packet_should_read_long_from_packet_and_return_code_in_hash
    packet = Net::SSH::Buffer.from(:long, 15)
    assert_equal({ :code => 15 }, @base.parse_status_packet(packet))
  end

  def test_parse_data_packet_should_read_string_from_packet_and_return_data_in_hash
    packet = Net::SSH::Buffer.from(:string, "here is a string")
    assert_equal({ :data => "here is a string" }, @base.parse_data_packet(packet))
  end

  def test_parse_attrs_packet_should_use_v1_attributes_class
    Net::SFTP::Protocol::V01::Attributes.expects(:from_buffer).with(:packet).returns(:result)
    assert_equal({ :attrs => :result }, @base.parse_attrs_packet(:packet))
  end

  def test_parse_name_packet_should_use_v1_name_class
    packet = Net::SSH::Buffer.from(:long, 2,
      :string, "name1", :string, "long1", :long, 0x4, :long, 0755,
      :string, "name2", :string, "long2", :long, 0x4, :long, 0550)
    names = @base.parse_name_packet(packet)[:names]

    assert_not_nil names
    assert_equal 2, names.length
    assert_instance_of Net::SFTP::Protocol::V01::Name, names.first

    assert_equal "name1", names.first.name
    assert_equal "long1", names.first.longname
    assert_equal 0755, names.first.attributes.permissions

    assert_equal "name2", names.last.name
    assert_equal "long2", names.last.longname
    assert_equal 0550, names.last.attributes.permissions
  end

  def test_open_with_numeric_flag_should_accept_IO_constants
    @session.expects(:send_packet).with(FXP_OPEN, :long, 0,
      :string, "/path/to/file",
      :long, Base::F_READ | Base::F_WRITE | Base::F_CREAT | Base::F_EXCL,
      :raw, raw(:long, 0)).returns(1)

    assert_equal 0, @base.open("/path/to/file", IO::RDWR | IO::CREAT | IO::EXCL, {})
  end

  def test_open_with_r_flag_should_translate_to_sftp_constants
    @session.expects(:send_packet).with(FXP_OPEN, :long, 0,
      :string, "/path/to/file", :long, Base::F_READ, :raw, raw(:long, 0)).returns(1)

    assert_equal 0, @base.open("/path/to/file", "r", {})
  end

  def test_open_with_b_flag_should_ignore_b_flag
    @session.expects(:send_packet).with(FXP_OPEN, :long, 0,
      :string, "/path/to/file", :long, Base::F_READ, :raw, raw(:long, 0)).returns(1)

    assert_equal 0, @base.open("/path/to/file", "rb", {})
  end

  def test_open_with_r_plus_flag_should_translate_to_sftp_constants
    @session.expects(:send_packet).with(FXP_OPEN, :long, 0,
      :string, "/path/to/file", :long, Base::F_READ | Base::F_WRITE,
      :raw, raw(:long, 0)).returns(1)

    assert_equal 0, @base.open("/path/to/file", "r+", {})
  end
end