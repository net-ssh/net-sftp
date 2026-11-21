require 'common'

class Protocol::TestBase < Net::SFTP::TestCase
  def setup
    @session = stub('session', :logger => nil, :pending_requests => {})
    @base = Net::SFTP::Protocol::Base.new(@session)
  end

  def test_parse_with_status_packet_should_delegate_to_parse_status_packet
    packet = stub('packet', :type => FXP_STATUS)
    @base.expects(:parse_status_packet).with(packet).returns(:result)
    assert_equal :result, @base.parse(packet)
  end

  def test_parse_with_handle_packet_should_delegate_to_parse_handle_packet
    packet = stub('packet', :type => FXP_HANDLE)
    @base.expects(:parse_handle_packet).with(packet).returns(:result)
    assert_equal :result, @base.parse(packet)
  end

  def test_parse_with_data_packet_should_delegate_to_parse_data_packet
    packet = stub('packet', :type => FXP_DATA)
    @base.expects(:parse_data_packet).with(packet).returns(:result)
    assert_equal :result, @base.parse(packet)
  end

  def test_parse_with_name_packet_should_delegate_to_parse_name_packet
    packet = stub('packet', :type => FXP_NAME)
    @base.expects(:parse_name_packet).with(packet).returns(:result)
    assert_equal :result, @base.parse(packet)
  end

  def test_parse_with_attrs_packet_should_delegate_to_parse_attrs_packet
    packet = stub('packet', :type => FXP_ATTRS)
    @base.expects(:parse_attrs_packet).with(packet).returns(:result)
    assert_equal :result, @base.parse(packet)
  end

  def test_parse_with_unknown_packet_should_raise_exception
    packet = stub('packet', :type => FXP_WRITE)
    assert_raises(NotImplementedError) { @base.parse(packet) }
  end

  def test_send_request_should_wrap_request_ids_at_uint32_boundary
    @base.instance_variable_set(:@request_id_counter, 0xfffffffe)
    @session.expects(:send_packet).with(FXP_READ, :long, 0xffffffff)
    @session.expects(:send_packet).with(FXP_READ, :long, 0)

    assert_equal 0xffffffff, @base.send(:send_request, FXP_READ)
    assert_equal 0, @base.send(:send_request, FXP_READ)
  end

  def test_send_request_should_skip_an_id_that_is_still_pending
    @base.instance_variable_set(:@request_id_counter, 0xffffffff)
    @session.stubs(:pending_requests).returns(0 => true)
    @session.expects(:send_packet).with(FXP_READ, :long, 1)

    assert_equal 1, @base.send(:send_request, FXP_READ)
  end
end
