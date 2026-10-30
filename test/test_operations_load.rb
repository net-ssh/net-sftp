require "common"
require "rbconfig"
require "open3"

class OperationsLoadTest < Net::SFTP::TestCase
  # Bundler and RubyGems load pathname themselves, so only a bare process shows a missing require.
  def test_transfer_operations_load_pathname_themselves
    skip "spawns MRI with --disable-gems" unless RUBY_ENGINE == "ruby"

    lib = File.expand_path("../lib", __dir__)
    loggable = $LOADED_FEATURES.find { |f| f.end_with?("/net/ssh/loggable.rb") }
    net_ssh_lib = File.dirname(File.dirname(File.dirname(loggable)))
    script = <<~RUBY
      require "net/sftp/operations/download"
      require "net/sftp/operations/upload"
      sftp = Object.new
      def sftp.logger; end
      def sftp.open(*); end
      [Net::SFTP::Operations::Download, Net::SFTP::Operations::Upload].each do |operation|
        begin
          operation.new(sftp, "/path/to/local", "/path/to/remote")
        rescue NameError => e
          abort e.message if e.name == :Pathname
        rescue StandardError
        end
      end
    RUBY

    out, status = Open3.capture2e({ "RUBYOPT" => nil }, RbConfig.ruby, "--disable-gems",
                                  "-I", lib, "-I", net_ssh_lib, "-e", script)
    assert status.success?, out
  end
end
