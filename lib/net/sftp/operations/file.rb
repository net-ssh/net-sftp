require 'net/ssh/loggable'
require 'net/sftp/operations/file'

module Net; module SFTP; module Operations

  class File
    attr_reader :sftp
    attr_reader :handle
    attr_reader :pos

    def initialize(sftp, handle)
      @sftp     = sftp
      @handle   = handle
      @pos      = 0
      @real_pos = 0
      @real_eof = false
      @buffer   = ""
    end

    def pos=(offset)
      @real_pos = @pos = offset
      @buffer = ""
      @real_eof = false
    end

    def close
      sftp.close!(handle)
      @handle = nil
    end

    def eof?
      @real_eof && @buffer.empty?
    end

    def read(n=nil)
      loop do
        break if n && @buffer.length >= n
        break unless fill
      end

      if n
        result, @buffer = @buffer[0,n], (@buffer[n..-1] || "")
      else
        result, @buffer = @buffer, ""
      end

      @pos += result.length
      return result
    end

    def gets(sep_string=$/)
      delim = if sep_string.length == 0
        "#{$/}#{$/}"
      else
        sep_string
      end

      loop do
        at = @buffer.index(sep_string)
        if at
          offset = at + sep_string.length
          @pos += offset
          line, @buffer = @buffer[0,offset], @buffer[offset..-1]
          return line
        elsif !fill
          return nil if @buffer.empty?
          @pos += @buffer.length
          line, @buffer = @buffer, ""
          return line
        end
      end
    end

    def readline(sep_string=$/)
      line = gets(sep_string)
      raise EOFError if line.nil?
      return line
    end

    def write(data)
      data = data.to_s
      sftp.write!(handle, @real_pos, data)
      @real_pos += data.length
      @pos = @real_pos
      data.length
    end

    def print(*items)
      items.each { |item| write(item) }
      write($\) if $\
      nil
    end

    def puts(*items)
      items.each do |item|
        if Array === item
          puts(*item)
        else
          write(item)
          write("\n") unless item[-1] == ?\n
        end
      end
      nil
    end

    def stat
      sftp.fstat!(handle)
    end

    private

      def fill
        data = sftp.read!(handle, @real_pos, 8192)

        if data.nil?
          @real_eof = true
          return false
        else
          @real_pos += data.length
          @buffer << data
        end

        !@real_eof
      end
  end

end; end; end
