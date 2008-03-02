require 'common'

class FileTest < Net::SFTP::TestCase
  # pos= should set pos
  # pos= should reset eof
  # close should close file and set handle to nil
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
end