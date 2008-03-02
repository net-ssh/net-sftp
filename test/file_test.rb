require 'common'

class FileOperationsTest < Net::SFTP::TestCase
  def setup
    @sftp = mock("sftp")
    @file = Net::SFTP::Operations::File.new(@sftp, "handle")
  end

  def test_pos_assignment_should_set_position
    @file.pos = 15
    assert_equal 15, @file.pos
  end

  def test_pos_assignment_should_reset_eof
    @sftp.expects(:read!).with("handle", 0, 8192).returns(nil)
    assert !@file.eof?
    @file.read
    assert @file.eof?
    @file.pos = 0
    assert !@file.eof?
  end

  def test_close_should_close_handle_and_set_handle_to_nil
    assert_equal "handle", @file.handle
    @sftp.expects(:close!).with("handle")
    @file.close
    assert_nil @file.handle
  end

  # eof? should be false if not at eof
  # eof? should be false if at eof but data in buffer
  # eof? should be true i f at eof and no data in buffer
  # read without argument should read and return remainder of file and set pos
  # read with argument should return and return n bytes and set pos
  # read after pos= should read from specified position
  # gets without argument should read until first $/
  # gets with empty argument should read until fist $/$/
  # gets with argument should read until first instance of argument
  # gets when no such delimiter exists in stream should read to EOF
  # gets should return nil at EOF
  # readline should call gets
  # readline should raise exception on EOF
  # write should write data and increment pos and return data length
  # print with no arguments should write nothing if $\ is nil
  # print with no arguments should write $\ if $\ is not nil
  # print with arguments should write all argument
  # puts should recursively puts array arguments
  # puts should print each argument and append '\n'
  # puts should not append newline if argument ends in newline
  # stat should return attributes object for handle

  private

    
end