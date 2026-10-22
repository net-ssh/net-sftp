require 'common'

class StartTest < Net::SFTP::TestCase
  def test_with_block
    ssh = mock('ssh')
    ssh.expects(:close)
    Net::SSH.expects(:start).with('host', 'user', {}).returns(ssh)

    sftp = mock('sftp')
    # TODO: figure out how to verify a block is passed, and call it later.
    # I suspect this is hard to do properly with mocha.
    Net::SFTP::Session.expects(:new).with(ssh, nil).returns(sftp)
    sftp.expects(:connect!).returns(sftp)
    sftp.expects(:loop)
    
    Net::SFTP.start('host', 'user') do
      # NOTE: currently not called!
    end
  end
  
  def test_with_block_and_options
    ssh = mock('ssh')
    ssh.expects(:close)
    Net::SSH.expects(:start).with('host', 'user', {auth_methods: ["password"]}).returns(ssh)

    sftp = mock('sftp')
    Net::SFTP::Session.expects(:new).with(ssh, 3).returns(sftp)
    sftp.expects(:connect!).returns(sftp)
    sftp.expects(:loop)
    
    Net::SFTP.start('host', 'user', {auth_methods: ["password"]}, {version: 3}) do
      # NOTE: currently not called!
    end
  end

  def test_with_block_should_close_session_on_throw
    ssh = mock('ssh')
    ssh.expects(:close)
    Net::SSH.expects(:start).with('host', 'user', {}).returns(ssh)

    sftp = mock('sftp')
    Net::SFTP::Session.expects(:new).with(ssh, nil).returns(sftp)
    sftp.expects(:connect!).returns(sftp)
    sftp.expects(:loop).throws(:done)

    catch(:done) { Net::SFTP.start('host', 'user') {} }
  end

  def test_with_block_should_shutdown_session_on_exception
    ssh = mock('ssh')
    ssh.expects(:shutdown!)
    Net::SSH.expects(:start).with('host', 'user', {}).returns(ssh)

    sftp = mock('sftp')
    Net::SFTP::Session.expects(:new).with(ssh, nil).returns(sftp)
    sftp.expects(:connect!).returns(sftp)
    sftp.expects(:loop).raises(RuntimeError, "boom")

    assert_raises(RuntimeError) { Net::SFTP.start('host', 'user') {} }
  end

  def test_without_block_should_not_close_session
    ssh = mock('ssh')
    Net::SSH.expects(:start).with('host', 'user', {}).returns(ssh)

    sftp = mock('sftp')
    Net::SFTP::Session.expects(:new).with(ssh, nil).returns(sftp)
    sftp.expects(:connect!).returns(sftp)

    assert_equal sftp, Net::SFTP.start('host', 'user')
  end
end
