require 'net/ssh/version'

module Net; module SFTP
  class Version < Net::SSH::Version
    MAJOR = 1
    MINOR = 99
    TINY  = 0

    CURRENT = new(MAJOR, MINOR, TINY)
    STRING  = CURRENT.to_s
  end
end; end