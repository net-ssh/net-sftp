require "#{File.dirname(__FILE__)}/common"

class BaseTest < Net::SFTP::TestCase
  (1..6).each do |version|
    define_method("test_server_reporting_version_#{version}_should_cause_version_#{version}_to_be_used") do
      expect_sftp_session :server_version => version
      assert_scripted { sftp.loop { sftp.base.opening? } }
      assert_equal version, sftp.base.protocol.version
    end
  end
end