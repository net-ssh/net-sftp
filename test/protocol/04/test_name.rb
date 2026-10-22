require 'common'

class Protocol::V04::TestName < Net::SFTP::TestCase
  def setup
    @save_tz   = ENV['TZ']
    ENV['TZ']  = 'UTC'

    @directory = Net::SFTP::Protocol::V04::Name.new("test", Net::SFTP::Protocol::V04::Attributes.new(:type => 2, :mtime => 1205293237, :owner => "jamis", :group => "users", :size => 1024, :permissions => 0755))
    @link      = Net::SFTP::Protocol::V04::Name.new("test", Net::SFTP::Protocol::V04::Attributes.new(:type => 3, :mtime => 1205293237, :owner => "jamis", :group => "users", :size => 32, :permissions => 0755))
    @file      = Net::SFTP::Protocol::V04::Name.new("test", Net::SFTP::Protocol::V04::Attributes.new(:type => 1, :mtime => 1205293237, :owner => "jamis", :group => "users", :size => 10240, :permissions => 0755))
  end

  def teardown
    if @save_tz
      ENV['TZ'] = @save_tz
    else
      ENV.delete('TZ')
    end
  end

  def test_directory?
    assert @directory.directory?
    assert !@link.directory?
    assert !@file.directory?
  end

  def test_symlink?
    assert !@directory.symlink?
    assert @link.symlink?
    assert !@file.symlink?
  end

  def test_file?
    assert !@directory.file?
    assert !@link.file?
    assert @file.file?
  end

  def test_longname_for_directory_should_format_as_directory
    assert_equal "drwxr-xr-x jamis    users        1024 Mar 12 03:40 test",
      @directory.longname
  end

  def test_longname_for_symlink_should_format_as_symlink
    assert_equal "lrwxr-xr-x jamis    users          32 Mar 12 03:40 test",
      @link.longname
  end

  def test_longname_for_file_should_format_as_file
    assert_equal "-rwxr-xr-x jamis    users       10240 Mar 12 03:40 test",
      @file.longname
  end

  def test_longname_should_tolerate_omitted_optional_attributes
    sparse = Net::SFTP::Protocol::V04::Name.new(
      "test",
      Net::SFTP::Protocol::V04::Attributes.new(:type => 1)
    )

    assert_equal "----------                          -              test", sparse.longname
  end

  def test_longname_without_mtime_should_leave_timestamp_blank
    assert_equal "-rwxr-xr-x jamis    users       10240              test",
      sparse_file(:mtime).longname
  end

  def test_longname_without_size_should_show_placeholder
    assert_equal "-rwxr-xr-x jamis    users           - Mar 12 03:40 test",
      sparse_file(:size).longname
  end

  def test_longname_without_permissions_should_show_no_permission_bits
    assert_equal "---------- jamis    users       10240 Mar 12 03:40 test",
      sparse_file(:permissions).longname
  end

  def test_longname_without_mtime_size_and_permissions_should_keep_columns_aligned
    assert_equal @file.longname.length, sparse_file(:mtime, :size, :permissions).longname.length
    assert_equal "---------- jamis    users           -              test",
      sparse_file(:mtime, :size, :permissions).longname
  end

  def test_longname_should_tolerate_sparse_v06_attributes
    name = Net::SFTP::Protocol::V04::Name.new("test", Net::SFTP::Protocol::V06::Attributes.new(:type => 2))
    assert_equal "d---------                          -              test", name.longname
  end

  private

  def sparse_file(*omitted)
    attributes = { :type => 1, :mtime => 1205293237, :owner => "jamis", :group => "users", :size => 10240, :permissions => 0755 }
    omitted.each { |key| attributes.delete(key) }
    Net::SFTP::Protocol::V04::Name.new("test", Net::SFTP::Protocol::V04::Attributes.new(attributes))
  end
end
