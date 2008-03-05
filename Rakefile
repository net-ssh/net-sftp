if ENV['REBUILD_MANIFEST']
  source_files = FileList.new do |fl|
    [ "lib", "test" ].each do |dir|
      fl.include "#{dir}/**/*"
    end

    fl.include "History.txt", "Manifest.txt", "README.txt"
    fl.include "Rakefile", "setup.rb"
  end

  File.open("Manifest.txt", "w") do |f|
    source_files.each do |file|
      next if File.directory?(file)
      f.puts(file)
    end
  end
end

$LOAD_PATH.unshift "../net-ssh/lib"
require './lib/net/sftp/version'

require 'hoe'

version = Net::SFTP::Version::STRING.dup
if ENV['SNAPSHOT'].to_i == 1
  version << "." << Time.now.utc.strftime("%Y%m%d%H%M%S")
end

Hoe.new('net-sftp', version) do |p|
  p.author         = "Jamis Buck"
  p.email          = "jamis@jamisbuck.org"
  p.summary        = "A pure Ruby implementation of the SFTP client protocol"
  p.url            = "http://net-ssh.rubyforge.org/sftp"
  p.extra_deps     << [["net-ssh", ">= 1.99.1"]]
  p.need_zip       = true
  p.rubyforge_name = "net-ssh"
end