require 'common'

class DirOperationsTest < Net::SFTP::TestCase
  def setup
    @sftp = mock("sftp")
    @dir = Net::SFTP::Operations::Dir.new(@sftp)
  end

  def test_foreach_should_iterate_over_all_entries_in_directory
    @sftp.expects(:opendir!).with("/path/to/remote").returns("handle")
    @sftp.expects(:readdir!).with("handle").returns([:e1, :e2, :e3], [:e4, :e5], nil).times(3)
    @sftp.expects(:close!).with("handle")

    entries = []
    @dir.foreach("/path/to/remote") { |entry| entries << entry }
    assert_equal [:e1, :e2, :e3, :e4, :e5], entries
  end

  def test_entries_should_return_all_entries_in_a_single_array
    @sftp.expects(:opendir!).with("/path/to/remote").returns("handle")
    @sftp.expects(:readdir!).with("handle").returns([:e1, :e2, :e3], [:e4, :e5], nil).times(3)
    @sftp.expects(:close!).with("handle")

    assert_equal [:e1, :e2, :e3, :e4, :e5], @dir.entries("/path/to/remote")
  end

  def test_glob_should_search_under_path_for_matching_entries
    @sftp.expects(:opendir!).with("/path/to/remote").returns("handle")
    @sftp.expects(:opendir!).with("/path/to/remote/e3").returns("handle-e3")
    @sftp.expects(:opendir!).with("/path/to/remote/e5").returns("handle-e5")
    @sftp.expects(:readdir!).with("handle").returns([n(".", true), n("..", true), n("e1"), n("e2"), n("e3", true)], [n("e4"), n("e5", true)], nil).times(3)
    @sftp.expects(:readdir!).with("handle-e3").returns([n(".", true), n("..", true), n("e3e1"), n("e3e2")], nil).times(2)
    @sftp.expects(:readdir!).with("handle-e5").returns([n(".", true), n("..", true), n("e5e1"), n("e5e2"), n("e5e3")], nil).times(2)
    @sftp.expects(:close!).with("handle")
    @sftp.expects(:close!).with("handle-e3")
    @sftp.expects(:close!).with("handle-e5")

    assert_equal %w(e3/e3e2 e5/e5e2), @dir.glob("/path/to/remote", "**/e?e2").map { |e| e.name }
  end

  def test_glob_without_slash_should_not_list_subdirectories
    expect_listing("/r", [n("a.txt"), n("sub", true), n("b.rb")])

    assert_equal %w(a.txt), @dir.glob("/r", "*.txt").map { |e| e.name }
  end

  def test_glob_without_slash_should_not_fail_on_unreadable_subdirectory
    expect_listing("/r", [n("a.txt"), n("locked", true)])
    response = stub("response", code: 3, message: "permission denied")
    @sftp.stubs(:opendir!).with("/r/locked").raises(Net::SFTP::StatusException.new(response))

    assert_equal %w(a.txt locked), @dir.glob("/r", "*").map { |e| e.name }
  end

  def test_glob_with_slash_should_descend_into_subdirectories
    expect_listing("/r", [n("a.txt"), n("sub", true)])
    expect_listing("/r/sub", [n("b.txt"), n("c.rb")])

    assert_equal %w(sub/b.txt), @dir.glob("/r", "sub/*.txt").map { |e| e.name }
  end

  def test_glob_should_yield_matches_in_breadth_first_order
    expect_listing("/r", [n("a", true), n("b.txt"), n("c", true)])
    expect_listing("/r/a", [n("a1.txt"), n("aa", true)])
    expect_listing("/r/c", [n("c1.txt")])
    expect_listing("/r/a/aa", [n("deep.txt")])

    names = []
    @dir.glob("/r", "**/*.txt") { |e| names << e.name }
    assert_equal %w(b.txt a/a1.txt c/c1.txt a/aa/deep.txt), names
  end

  def test_glob_should_not_modify_names_in_place
    deep = n("deep.txt".freeze)
    expect_listing("/r", [n("sub", true)])
    expect_listing("/r/sub", [deep])

    assert_equal %w(sub/deep.txt), @dir.glob("/r", "**/*.txt").map { |e| e.name }
    assert_equal "sub/deep.txt", deep.name
  end

  private

    def expect_listing(path, names)
      handle = "handle:#{path}"
      @sftp.expects(:opendir!).with(path).returns(handle)
      @sftp.expects(:readdir!).with(handle).returns([n(".", true), n("..", true)] + names, nil).times(2)
      @sftp.expects(:close!).with(handle)
    end

    def n(name, directory=false)
      Net::SFTP::Protocol::V01::Name.new(name.to_s, "longname for #{name}",
        Net::SFTP::Protocol::V01::Attributes.new(:permissions => directory ? 040755 : 0100644))
    end
end