require 'zpng'
require 'optparse'
require 'pp'

class ZPNG::CLI

  ACTIONS = {
    'info'      => 'General image info',
    'chunks'    => 'Show file chunks (default)',
    'ascii'     => 'Try to display image as ASCII (works best with monochrome images)',
    'scanlines' => 'Show scanlines info'
  }
  DEFAULT_ACTIONS = %w'info chunks'

  def initialize argv = ARGV
    @argv = argv
  end

  def run
    @actions = []
    @options = { :verbose => 0 }
    optparser = OptionParser.new do |opts|
      opts.banner = "Usage: zpng [options]"

      opts.on "-v", "--verbose", "Run verbosely (can be used multiple times)" do |v|
        @options[:verbose] += 1
      end
      opts.on "-q", "--quiet", "Silent any warnings (can be used multiple times)" do |v|
        @options[:verbose] -= 1
      end

      ACTIONS.each do |t,desc|
        opts.on *[ "-#{t[0].upcase}", "--#{t}", desc, eval("lambda{ |_| @actions << :#{t} }") ]
      end
    end

    if (argv = optparser.parse(@argv)).empty?
      puts optparser.help
      return
    end

    @actions = DEFAULT_ACTIONS if @actions.empty?

    argv.each_with_index do |fname,idx|
      @need_fname_header = (argv.size > 1)
      @file_idx  = idx
      @file_name = fname

      @zpng = load_file fname

      @actions.each do |action|
        self.send(action) if self.respond_to?(action)
      end
    end
  rescue Errno::EPIPE
    # output interrupt, f.ex. when piping output to a 'head' command
    # prevents a 'Broken pipe - <STDOUT> (Errno::EPIPE)' message
  end

  def load_file fname
    @img = ZPNG::Image.new fname
  end

  def info
    puts "[.] image size #{@img.width}x#{@img.height}"
    puts "[.] uncompressed imagedata size = #{@img.imagedata.size} bytes"
    puts "[.] palette = #{@img.palette}" if @img.palette
  end

  def chunks
    @img.dump
  end

  def ascii
    puts @img.to_s
  end

  def scanlines
    pp @img.scanlines
  end
end
