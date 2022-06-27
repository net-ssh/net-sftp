require_relative 'lib/net/sftp/version'

Gem::Specification.new do |spec|
  spec.name          = "net-sftp"
  spec.version       = Net::SFTP::Version::STRING
  spec.authors       = ["Jamis Buck", "Delano Mandelbaum", "Mikl\u{f3}s Fazekas"]
  spec.email         = ["net-ssh@solutious.com"]

  if ENV['NET_SSH_BUILDGEM_SIGNED']
    spec.cert_chain = ["net-sftp-public_cert.pem"]
    spec.signing_key = "/mnt/gem/net-ssh-private_key.pem"
  end

  spec.summary       = %q{A pure Ruby implementation of the SFTP client protocol.}
  spec.description   = %q{A pure Ruby implementation of the SFTP client protocol}
  spec.homepage      = "https://github.com/net-ssh/net-sftp"
  spec.license       = "MIT"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  spec.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  if spec.respond_to? :specification_version then
    spec.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      spec.add_runtime_dependency(%q<net-ssh>, [">= 5.0.0", "< 8.0.0"])
      spec.add_development_dependency(%q<minitest>, [">= 5"])
      spec.add_development_dependency(%q<mocha>, [">= 0"])
    else
      spec.add_dependency(%q<net-ssh>, [">= 5.0.0", "< 8.0.0"])
      spec.add_dependency(%q<minitest>, [">= 5"])
      spec.add_dependency(%q<mocha>, [">= 0"])
    end
  else
    spec.add_dependency(%q<net-ssh>, [">= 5.0.0", "< 8.0.0"])
    spec.add_dependency(%q<minitest>, [">= 5"])
    spec.add_dependency(%q<test-unit>, [">= 0"])
    spec.add_dependency(%q<mocha>, [">= 0"])
  end
end
