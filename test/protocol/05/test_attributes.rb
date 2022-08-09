require 'common'

module Etc; end

class Protocol::V05::TestAttributes < Net::SFTP::TestCase
  def test_from_buffer_should_correctly_parse_buffer_and_return_attribute_object
    attributes = attributes_factory.from_buffer(full_buffer)

    assert_equal 9, attributes.type
    assert_equal 1234567890, attributes.size
    assert_equal "jamis", attributes.owner
    assert_equal "users", attributes.group
    assert_equal 0755, attributes.permissions
    assert_equal 1234567890, attributes.atime
    assert_equal 12345, attributes.atime_nseconds
    assert_equal 2345678901, attributes.createtime
    assert_equal 23456, attributes.createtime_nseconds
    assert_equal 3456789012, attributes.mtime
    assert_equal 34567, attributes.mtime_nseconds

    assert_equal 2, attributes.acl.length

    assert_equal 1, attributes.acl.first.type
    assert_equal 2, attributes.acl.first.flag
    assert_equal 3, attributes.acl.first.mask
    assert_equal "foo", attributes.acl.first.who

    assert_equal 4, attributes.acl.last.type
    assert_equal 5, attributes.acl.last.flag
    assert_equal 6, attributes.acl.last.mask
    assert_equal "bar", attributes.acl.last.who

    assert_equal 0x12341234, attributes.attrib_bits

    assert_equal "second", attributes.extended["first"]
  end

  def test_attributes_to_s_should_build_binary_representation
    attributes = attributes_factory.new(
      :type => 9,
      :size => 1234567890,
      :owner  => "jamis", :group => "users",
      :permissions => 0755,
      :atime => 1234567890, :atime_nseconds => 12345,
      :createtime => 2345678901, :createtime_nseconds => 23456,
      :mtime => 3456789012, :mtime_nseconds => 34567,
      :acl => [attributes_factory::ACL.new(1,2,3,"foo"),
               attributes_factory::ACL.new(4,5,6,"bar")],
      :attrib_bits => 0x12341234,
      :extended => { "first" => "second" })

    assert_equal full_buffer.to_s, attributes.to_s
  end

  def test_attributes_to_s_should_build_binary_representation_when_subset_is_present
    attributes = attributes_factory.new(:permissions => 0755)
    assert_equal Net::SSH::Buffer.from(:long, 0x4, :byte, 1, :long, 0755).to_s, attributes.to_s
  end

  private

    def full_buffer
      Net::SSH::Buffer.from(:long, 0x800003fd,
        :byte, 9, :int64, 1234567890,
        :string, "jamis", :string, "users",
        :long, 0755,
        :int64, 1234567890, :long, 12345,
        :int64, 2345678901, :long, 23456,
        :int64, 3456789012, :long, 34567,
        :string, raw(:long, 2,
          :long, 1, :long, 2, :long, 3, :string, "foo",
          :long, 4, :long, 5, :long, 6, :string, "bar"),
        :long, 0x12341234,
        :long, 1, :string, "first", :string, "second")
    end

    def attributes_factory
      Net::SFTP::Protocol::V05::Attributes
    end
end
