require 'common'
require 'timeout'

class FileOperationsTest < Net::SFTP::TestCase
  def setup
    @sftp = mock("sftp")
    @file = Net::SFTP::Operations::File.new(@sftp, "handle")
    @save_dollar_fslash, $/ = $/, "\n"
    @save_dollar_bslash, $\ = $\, nil
  end

  def teardown
    $/ = @save_dollar_fslash
    $\ = @save_dollar_bslash
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

  def test_eof_should_be_false_if_at_eof_but_data_remains_in_buffer
    @sftp.expects(:read!).returns("hello world", nil)
    @file.read(1)
    assert !@file.eof?
  end

  def test_eof_should_be_true_if_at_eof_and_no_data_in_buffer
    @sftp.expects(:read!).times(2).returns("hello world", nil)
    @file.read
    assert @file.eof?
  end

  def test_read_without_argument_should_read_and_return_remainder_of_file_and_set_pos
    @sftp.expects(:read!).times(2).returns("hello world", nil)
    assert_equal "hello world", @file.read
    assert_equal 11, @file.pos
  end

  def test_read_with_argument_should_read_and_return_n_bytes_and_set_pos
    @sftp.expects(:read!).returns("hello world")
    assert_equal "hello", @file.read(5)
    assert_equal 5, @file.pos
  end

  def test_read_with_negative_length_should_raise_argument_error
    @sftp.expects(:read!).never
    assert_raises(ArgumentError) { @file.read(-1) }
  end

  def test_read_with_argument_at_eof_should_return_empty_string
    @sftp.expects(:read!).returns(nil)
    assert_equal "", @file.read(1)
  end

  def test_read_should_treat_empty_data_response_as_eof
    @sftp.expects(:read!).once.returns("")
    assert_equal "", Timeout.timeout(5) { @file.read }
    assert @file.eof?
  end

  def test_read_with_argument_should_treat_empty_data_response_as_eof
    @sftp.expects(:read!).twice.returns("hello", "")
    assert_equal "hello", Timeout.timeout(5) { @file.read(10) }
    assert @file.eof?
  end

  def test_read_after_pos_assignment_should_read_from_specified_position
    @sftp.expects(:read!).with("handle", 5, 8192).returns("hello world")
    @file.pos = 5
    assert_equal "hello", @file.read(5)
    assert_equal 10, @file.pos
  end

  def test_gets_without_argument_should_read_until_first_dollar_fslash
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "\n", $/
    assert_equal "hello world\n", @file.gets
    assert_equal 12, @file.pos
  end

  def test_gets_with_empty_argument_should_read_until_double_dollar_fslash
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "\n", $/
    assert_equal "hello world\ngoodbye world\n\n", @file.gets("")
    assert_equal 27, @file.pos
  end

  def test_gets_with_argument_should_read_until_first_instance_of_argument
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello w", @file.gets("w")
    assert_equal 7, @file.pos
  end

  def test_gets_when_no_such_delimiter_exists_in_stream_should_read_to_EOF
    @sftp.expects(:read!).times(2).returns("hello world\ngoodbye world\n\nfarewell!\n", nil)
    assert_equal "hello world\ngoodbye world\n\nfarewell!\n", @file.gets("X")
    assert @file.eof?
  end

  def test_gets_when_nil_delimiter_should_fread_to_EOF
    @sftp.expects(:read!).times(2).returns("hello world\ngoodbye world\n\nfarewell!\n", nil)
    assert_equal "hello world\ngoodbye world\n\nfarewell!\n", @file.gets(nil)
    assert @file.eof?
  end

  def test_gets_with_integer_argument_should_read_number_of_bytes
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello w", @file.gets(7)
  end

  def test_gets_with_delimiter_and_limit_should_read_to_delimiter_if_less_than_limit
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello w", @file.gets("w", 11)
  end

  def test_gets_with_delimiter_and_limit_should_read_to_limit_if_less_than_delimiter
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello", @file.gets("w", 5)
  end

  def test_gets_when_no_such_delimiter_exists_in_stream_but_limit_provided_should_read_to_limit
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello w", @file.gets("z", 7)
  end

  def test_gets_when_nil_delimiter_and_limit_provided_should_read_to_limit
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello w", @file.gets(nil, 7)
  end

  def test_gets_with_delimiter_and_negative_limit_should_read_to_delimiter
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello world\n", @file.gets("\n", -1)
    assert_equal 12, @file.pos
  end

  def test_gets_with_negative_integer_argument_should_read_to_dollar_fslash
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello world\n", @file.gets(-1)
    assert_equal 12, @file.pos
  end

  def test_gets_with_delimiter_and_nil_limit_should_read_to_delimiter
    @sftp.expects(:read!).returns("hello world\ngoodbye world\n\nfarewell!\n")
    assert_equal "hello world\n", @file.gets("\n", nil)
    assert_equal 12, @file.pos
  end

  def test_gets_should_find_crlf_split_across_reads
    @sftp.expects(:read!).times(2).returns("hello\r", "\nworld\r\n")
    assert_equal "hello\r\n", @file.gets("\r\n")
    assert_equal 7, @file.pos
    assert_equal "world\r\n", @file.gets("\r\n")
    assert_equal 14, @file.pos
  end

  def test_gets_should_find_multichar_delimiter_split_across_reads
    @sftp.expects(:read!).times(2).returns("xxa", "byy")
    assert_equal "xxab", @file.gets("ab")
    assert_equal 4, @file.pos
  end

  def test_gets_should_find_delimiter_after_repeated_prefix_across_reads
    @sftp.expects(:read!).times(3).returns("xa", "a", "b")
    assert_equal "xaab", @file.gets("ab")
    assert_equal 4, @file.pos
  end

  def test_gets_should_return_line_spanning_several_reads
    @sftp.expects(:read!).times(4).returns("a" * 8192, "b" * 8192, "c" * 100 + "\nrest", nil)
    assert_equal "a" * 8192 + "b" * 8192 + "c" * 100 + "\n", @file.gets
    assert_equal 16385 + 100, @file.pos
    assert_equal "rest", @file.gets
    assert @file.eof?
  end

  def test_gets_with_empty_argument_should_find_paragraph_split_across_reads
    @sftp.expects(:read!).times(2).returns("one\n", "\ntwo\n\n")
    assert_equal "one\n\n", @file.gets("")
    assert_equal 5, @file.pos
  end

  def test_gets_when_nil_delimiter_should_read_several_reads_to_EOF
    @sftp.expects(:read!).times(3).returns("one\n", "two\n", nil)
    assert_equal "one\ntwo\n", @file.gets(nil)
    assert @file.eof?
  end

  def test_gets_should_search_only_new_data_after_each_read
    offsets = []
    buffer = @file.instance_variable_get(:@buffer)
    buffer.define_singleton_method(:index) { |*args| offsets << args[1]; super(*args) }
    @sftp.expects(:read!).times(3).returns("aaaaa", "aaaaa", "a\r\n")
    assert_equal "aaaaaaaaaaa\r\n", @file.gets("\r\n")
    assert_equal [0, 0, 4, 9], offsets
  end

  def test_gets_with_limit_satisfied_by_buffer_should_not_read_again
    @sftp.expects(:read!).with("handle", 0, 8192).once.returns("a" * 8192)
    assert_equal "a" * 8192, @file.gets(8192)
    assert_equal 8192, @file.pos
  end

  def test_gets_after_exactly_satisfied_limit_should_return_remainder_then_nil
    @sftp.expects(:read!).with("handle", 0, 8192).once.returns("a" * 8192)
    @sftp.expects(:read!).with("handle", 8192, 8192).once.returns("b")
    @sftp.expects(:read!).with("handle", 8193, 8192).at_least_once.returns(nil)
    assert_equal "a" * 8192, @file.gets(8192)
    assert !@file.eof?
    assert_equal "b", @file.gets
    assert_equal 8193, @file.pos
    assert_nil @file.gets
    assert @file.eof?
  end

  def test_gets_with_zero_limit_should_return_empty_string_even_at_EOF
    @sftp.expects(:read!).times(2).returns("hello", nil)
    assert_equal "", @file.gets(0)
    assert_equal 0, @file.pos
    assert_equal "hello", @file.read
    assert @file.eof?
    assert_equal "", @file.gets(0)
  end

  def test_gets_at_EOF_should_return_nil
    @sftp.expects(:read!).returns(nil)
    assert_nil @file.gets
    assert @file.eof?
  end

  def test_gets_should_treat_empty_data_response_as_eof
    @sftp.expects(:read!).twice.returns("hello", "")
    assert_equal "hello", Timeout.timeout(5) { @file.gets }
    assert @file.eof?
  end

  def test_readline_should_raise_exception_on_EOF
    @sftp.expects(:read!).returns(nil)
    assert_raises(EOFError) { @file.readline }
  end

  def test_rewind_should_reset_to_beginning_of_file
    @sftp.expects(:read!).times(2).returns("hello world", nil)
    @file.read
    assert @file.eof?
    @file.rewind
    assert !@file.eof?
    assert_equal 0, @file.pos
  end

  def test_rewind
    @sftp.expects(:write!).with("handle", 0, "hello world\n")
    @sftp.expects(:read!).with("handle", 12, 8192).returns("hello world\n")
    @sftp.expects(:read!).with("handle", 0, 8192).returns("hello world\n")
    @file.puts "hello world\n"
    assert_equal "hello", @file.read(5)
    @file.rewind
    assert_equal "hello world", @file.read(11)
  end

  def test_write_should_write_data_and_increment_pos_and_return_data_length
    @sftp.expects(:write!).with("handle", 0, "hello world")
    assert_equal 11, @file.write("hello world")
    assert_equal 11, @file.pos
  end

  def test_write_after_pos_assignment_should_write_at_position
    @sftp.expects(:write!).with("handle", 15, "hello world")
    @file.pos = 15
    assert_equal 11, @file.write("hello world")
    assert_equal 26, @file.pos
  end

  def test_write_after_buffered_read_should_write_at_logical_position
    @sftp.expects(:read!).with("handle", 0, 8192).returns("hello world")
    @sftp.expects(:write!).with("handle", 2, "XY")
    assert_equal "he", @file.read(2)
    assert_equal 2, @file.write("XY")
    assert_equal 4, @file.pos
  end

  def test_read_after_write_should_read_from_new_position
    @sftp.expects(:read!).with("handle", 0, 8192).returns("hello world")
    @sftp.expects(:write!).with("handle", 2, "XY")
    @sftp.expects(:read!).with("handle", 4, 8192).returns("o world")
    @file.read(2)
    @file.write("XY")
    assert_equal "o w", @file.read(3)
    assert_equal 7, @file.pos
  end

  def test_write_should_write_mutlibyte_string_data_and_increment_pos_and_return_data_length
    @sftp.expects(:write!).with("handle", 0, "hello world, 你好，世界")
    assert_equal 28, @file.write("hello world, 你好，世界")
    assert_equal 28, @file.pos
  end

  def test_write_should_split_large_data_into_chunks_at_consecutive_offsets
    data = Random.new(99).bytes(100_000)
    sequence = sequence("writes")
    [0, 32_768, 65_536, 98_304].each do |offset|
      @sftp.expects(:write!).with("handle", 10 + offset, data.byteslice(offset, 32_768)).in_sequence(sequence)
    end
    @file.pos = 10
    assert_equal 100_000, @file.write(data)
    assert_equal 100_010, @file.pos
  end

  def test_write_should_split_multibyte_data_on_byte_boundaries
    data = "你好" * 10_000
    chunks = []
    @sftp.expects(:write!).times(2).with { |handle, offset, chunk| chunks << [offset, chunk.b] }
    assert_equal 60_000, @file.write(data)
    assert_equal [0, 32_768], chunks.map(&:first)
    assert_equal data.b, chunks.map(&:last).join
    assert_equal 60_000, @file.pos
  end

  def test_write_should_stop_at_failed_chunk_and_keep_pos_at_bytes_written
    data = "x" * 100_000
    response = stub("response", ok?: false, eof?: false, code: 4, message: "failure")
    @sftp.expects(:write!).with("handle", 0, data.byteslice(0, 32_768))
    @sftp.expects(:write!).with("handle", 32_768, data.byteslice(32_768, 32_768)).raises(Net::SFTP::StatusException.new(response))
    assert_raises(Net::SFTP::StatusException) { @file.write(data) }
    assert_equal 32_768, @file.pos
  end

  def test_print_with_no_arguments_should_write_nothing_if_dollar_bslash_is_nil
    assert_nil $\
    @sftp.expects(:write!).never
    @file.print
  end

  def test_print_with_no_arguments_should_write_dollar_bslash_if_dollar_bslash_is_not_nil
    $\ = "-"
    @sftp.expects(:write!).with("handle", 0, "-")
    @file.print
  end

  def test_print_with_arguments_should_write_all_arguments
    @sftp.expects(:write!).with("handle", 0, "hello")
    @sftp.expects(:write!).with("handle", 5, " ")
    @sftp.expects(:write!).with("handle", 6, "world")
    @file.print("hello", " ", "world")
  end

  def test_puts_should_recursively_puts_array_arguments
    10.times do |i|
      @sftp.expects(:write!).with("handle", i*2, i.to_s)
      @sftp.expects(:write!).with("handle", i*2+1, "\n")
    end
    @file.puts 0, [1, [2, 3], 4, [5, [6, 7, 8]]], 9
  end

  def test_puts_should_not_append_newline_if_argument_ends_in_newline
    @sftp.expects(:write!).with("handle", 0, "a")
    @sftp.expects(:write!).with("handle", 1, "\n")
    @sftp.expects(:write!).with("handle", 2, "b\n")
    @sftp.expects(:write!).with("handle", 4, "c")
    @sftp.expects(:write!).with("handle", 5, "\n")
    @file.puts "a", "b\n", "c"
  end

  def test_puts_without_arguments_should_write_newline
    assert_puts_like_io
  end

  def test_puts_should_write_newline_for_nil
    assert_puts_like_io nil
  end

  def test_puts_should_write_newline_for_array_containing_nil
    assert_puts_like_io [nil]
  end

  def test_puts_should_write_false_as_string
    assert_puts_like_io false
  end

  # Not compared with StringIO, whose puts([]) writes a newline on JRuby.
  def test_puts_should_write_nothing_for_empty_array
    @sftp.expects(:write!).never
    assert_nil @file.puts([])
  end

  def test_puts_should_not_double_newline
    assert_puts_like_io "a\n", "b"
  end

  def test_puts_should_convert_numbers_and_symbols
    assert_puts_like_io 1, :sym
  end

  def test_puts_should_ignore_output_record_separator
    old_separator, $\ = $\, "!"
    assert_puts_like_io "a"
  ensure
    $\ = old_separator
  end

  def test_puts_should_expand_objects_convertible_to_arrays
    item = stub("array-like")
    item.stubs(:to_ary).returns(["a", ["b"]])
    @sftp.expects(:write!).with("handle", 0, "a")
    @sftp.expects(:write!).with("handle", 1, "\n")
    @sftp.expects(:write!).with("handle", 2, "b")
    @sftp.expects(:write!).with("handle", 3, "\n")

    @file.puts(item)
  end

  def test_puts_should_terminate_recursive_arrays
    item = []
    item << item
    @sftp.expects(:write!).with("handle", 0, "[...]")
    @sftp.expects(:write!).with("handle", 5, "\n")

    @file.puts(item)
  end

  def test_puts_should_terminate_recursive_array_conversion
    item = Object.new
    item.define_singleton_method(:to_ary) { [self] }
    @sftp.expects(:write!).with("handle", 0, "[...]")
    @sftp.expects(:write!).with("handle", 5, "\n")

    @file.puts(item)
  end

  def test_stat_should_return_attributes_object_for_handle
    stat = stub("stat")
    @sftp.expects(:fstat!).with("handle").returns(stat)
    assert_equal stat, @file.stat
  end

  def test_size_should_return_size_from_stat
    stat = stub(size: 1024)
    @sftp.expects(:fstat!).with("handle").returns(stat)
    assert_equal 1024, @file.size
  end

  private

    def assert_puts_like_io(*items)
      expected = StringIO.new
      expected.puts(*items)
      writes = []
      @sftp.stubs(:write!).with { |handle, offset, data| writes << [handle, offset, data] }
      assert_nil @file.puts(*items)

      offset = 0
      writes.each do |handle, at, data|
        assert_equal ["handle", offset], [handle, at]
        refute_empty data
        offset += data.bytesize
      end
      assert_equal expected.string, writes.map(&:last).join
    end

end
