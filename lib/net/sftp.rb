require 'net/ssh'
require 'net/sftp/session'

module Net; module SFTP

  # A convenience method for starting a standalone SFTP session. It will
  # start up an SSH session using the given arguments (see the documentation
  # for Net::SSH::Session for details), and will then start a new SFTP session
  # with the SSH session. If a block is given, it will be passed to the SFTP
  # session.
  def self.start(*args, &block)
    session = Net::SSH.start(*args)
    sftp = Net::SFTP::Session.new(session, &block)

    if block_given?
      session.loop { sftp.state != :open }
      sftp.loop
    end
  ensure
    session.close if session && block_given?
  end

end; end

class Net::SSH::Connection::Session
  def sftp
    @sftp ||= Net::SFTP::Session.new(self)
  end
end