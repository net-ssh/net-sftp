require './lib/net/sftp/version'

Gem::Specification.new do |s|

  s.name = 'net-sftp'
  s.version = Net::SFTP::Version::STRING
  s.platform = Gem::Platform::RUBY
  s.summary = "Net::SFTP is a pure-Ruby implementation of the SFTP client protocol, supporting protocol versions 1 to 6."
  s.files = Dir.glob("{lib,test}/**/*")
  s.require_path = 'lib'

  s.has_rdoc = true

  s.author = "Jamis Buck"
  s.email = "jamis@37signals.com"
  s.homepage = "http://net-ssh.rubyforge.org"

end
