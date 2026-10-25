require 'net/ssh'
require 'net/sftp/session'

module Net

  # Net::SFTP is a pure-Ruby module for programmatically interacting with a
  # remote host via the SFTP protocol (that's SFTP as in "Secure File Transfer
  # Protocol" produced by the Secure Shell Working Group, not "Secure FTP"
  # and certainly not "Simple FTP").
  #
  # See Net::SFTP#start for an introduction to the library. Also, see
  # Net::SFTP::Session for further documentation.
  module SFTP
    # A convenience method for starting a standalone SFTP session. It will
    # start up an SSH session using the given arguments (see the documentation
    # for Net::SSH::Session for details), and will then start a new SFTP session
    # with the SSH session. This will block until the new SFTP is fully open
    # and initialized before returning it.
    #
    #   sftp = Net::SFTP.start("localhost", "user")
    #   sftp.upload! "/local/file.tgz", "/remote/file.tgz"
    #
    # If a block is given, it will be passed to the SFTP session and will be
    # called once the SFTP session is fully open and initialized. When the
    # block terminates, the new SSH session will automatically be closed.
    #
    #   Net::SFTP.start("localhost", "user") do |sftp|
    #     sftp.upload! "/local/file.tgz", "/remote/file.tgz"
    #   end
    #
    # Extra parameters can be passed:
    # - The Net::SSH connection options (see Net::SSH for more information)
    # - The Net::SFTP connection options:
    #   - :version, the SFTP protocol version to offer the server
    #   - :min_version, the lowest SFTP protocol version to accept; a server
    #     that negotiates an older one raises Net::SFTP::Exception
    def self.start(host, user, ssh_options={}, sftp_options={}, &block)
      session = Net::SSH.start(host, user, ssh_options)
      begin
        version = sftp_options.fetch(:version, nil)
        min_version = sftp_options.fetch(:min_version, nil)
        sftp = Net::SFTP::Session.new(session, version, min_version: min_version, &block).connect!

        if block_given?
          sftp.loop
          return nil
        end

        sftp
      rescue Object
        failed = true
        raise
      ensure
        session.close if block_given? && !failed
      end
    rescue Object => anything
      begin
        session.shutdown!
      rescue ::Exception
        # swallow exceptions that occur while trying to shutdown
      end

      raise anything
    end
  end

end

class Net::SSH::Connection::Session
  # A convenience method for starting up a new SFTP connection on the current
  # SSH session. Blocks until the SFTP session is fully open, and then
  # returns the SFTP session.
  #
  #   Net::SSH.start("localhost", "user", :password => "password") do |ssh|
  #     ssh.sftp.upload!("/local/file.tgz", "/remote/file.tgz")
  #     ssh.exec! "cd /some/path && tar xf /remote/file.tgz && rm /remote/file.tgz"
  #   end
  def sftp(wait=true)
    @sftp ||= begin
      sftp = Net::SFTP::Session.new(self)
      sftp.connect! if wait
      sftp
    end
  end
end
