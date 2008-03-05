= Net::SFTP

* http://net-ssh.rubyforge.org/sftp

== DESCRIPTION:

Net::SFTP is a pure-Ruby implementation of the SFTP protocol (specifically, versions 1 through 6 of the SFTP protocol). Note that this is the "Secure File Transfer Protocol", typically run over an SSH connection, and has nothing to do with the FTP protocol.

== FEATURES/PROBLEMS:

* Transfer files or even entire directory trees to or from a remote host via SFTP
* Completely supports all six protocol versions
* Asynchronous and synchronous operation
* Read and write files using an IO-like interface

== SYNOPSIS:

  require 'net/sftp'

  Net::SFTP.start('host', 'username', 'password') do |sftp|
    sftp.download!("/path/to/remote", "/path/to/local")
  end

== REQUIREMENTS:

* Net::SSH 2

If you wish to run the tests, you'll need:

* Hoe
* Mocha

== INSTALL:

* sudo gem install net-sftp

Or, if you prefer to do it the hard way (sans Rubygems):

* tar xzf net-ssh-*.tgz
* cd net-ssh-*
* ruby setup.rb config
* sudo ruby setup.rb install

== LICENSE:

(The MIT License)

Copyright (c) 2008 Jamis Buck <jamis@37signals.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
