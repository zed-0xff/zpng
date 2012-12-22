require 'zpng'
require 'optparse'
require 'hexdump'
require 'pp'

class ZPNG::CLI

  ACTIONS = {
    'chunks'    => 'Show file chunks (default)',
    %w'i info'      => 'General image info (default)',
    'scanlines' => 'Show scanlines info',
    'palette'   => 'Show palette'
  }
  DEFAULT_ACTIONS = %w'info chunks'

  def initialize argv = ARGV
    @argv = argv
  end

  def run
    @actions = []
    @options = { :verbose => 0 }
    optparser = OptionParser.new do |opts|
      opts.banner = "Usage: zpng [options] filename.png"

      opts.on "-v", "--verbose", "Run verbosely (can be used multiple times)" do |v|
        @options[:verbose] += 1
      end
      opts.on "-q", "--quiet", "Silent any warnings (can be used multiple times)" do |v|
        @options[:verbose] -= 1
      end

      ACTIONS.each do |t,desc|
        if t.is_a?(Array)
          opts.on *[ "-#{t[0]}", "--#{t[1]}", desc, eval("lambda{ |_| @actions << :#{t[1]} }") ]
        else
          opts.on *[ "-#{t[0].upcase}", "--#{t}", desc, eval("lambda{ |_| @actions << :#{t} }") ]
        end
      end

      opts.on "-E", "--extract-chunk ID", "extract a single chunk" do |id|
        @actions << [:extract_chunk, id.to_i]
      end
      opts.on "-D", "--imagedata", "dump unpacked Image Data (IDAT) chunk(s) to stdout" do
        @actions << :unpack_imagedata
      end

      opts.separator ""
      opts.on "-c", "--crop GEOMETRY", "crop image, {WIDTH}x{HEIGHT}+{X}+{Y},",
      "puts results on stdout unless --ascii given" do |x|
        @actions << [:crop, x]
      end

      opts.separator ""
      opts.on "-A", '--ascii', 'Try to convert image to ASCII (works best with monochrome images)' do
        @actions << :ascii
      end
      opts.on "-N", '--ansi', 'Try to display image as ANSI colored text' do
        @actions << :ansi
      end
      opts.on "-2", '--256', 'Try to display image as 256-colored text' do
        @actions << :ansi256
      end
      opts.on "-W", '--wide', 'Use 2 horizontal characters per one pixel' do
        @options[:wide] = true
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
        if action.is_a?(Array)
          self.send(*action) if self.respond_to?(action.first)
        else
          self.send(action) if self.respond_to?(action)
        end
      end
    end
  rescue Errno::EPIPE
    # output interrupt, f.ex. when piping output to a 'head' command
    # prevents a 'Broken pipe - <STDOUT> (Errno::EPIPE)' message
  end

  def extract_chunk id
    @img.chunks.each do |chunk|
      if chunk.idx == id
        case chunk
        when ZPNG::Chunk::ZTXT
          print chunk.text
        else
          print chunk.data
        end
      end
    end
  end

  def unpack_imagedata
    print @img.imagedata
  end

  def crop geometry
    unless geometry =~ /\A(\d+)x(\d+)\+(\d+)\+(\d+)\Z/i
      STDERR.puts "[!] invalid geometry #{geometry.inspect}, must be WxH+X+Y, like 100x100+10+10"
      exit 1
    end
    @img.crop! :width => $1.to_i, :height => $2.to_i, :x => $3.to_i, :y => $4.to_i
    print @img.export unless @actions.include?(:ascii)
  end

  def load_file fname
    @img = ZPNG::Image.new fname
  end

  def info
    puts "[.] image size #{@img.width || '?'}x#{@img.height || '?'}"
    puts "[.] uncompressed imagedata size = #{@img.imagedata.size} bytes"
    puts "[.] palette = #{@img.palette}" if @img.palette
  end

  def chunks
    @img.dump
  end

  def ascii
    @img.height.times do |y|
      @img.width.times do |x|
        c = @img[x,y].to_ascii
        c *= 2 if @options[:wide]
        print c
      end
      puts
    end
  end

  def ansi
    spc = @options[:wide] ? "  " : " "
    @img.height.times do |y|
      @img.width.times do |x|
        print spc.background(@img[x,y].closest_ansi_color)
      end
      puts
    end
  end

  def ansi256
    require 'rainbow'
    spc = @options[:wide] ? "  " : " "
    @img.height.times do |y|
      @img.width.times do |x|
        print spc.background(@img[x,y].to_s)
      end
      puts
    end
  end

  def scanlines
    @img.scanlines.each do |sl|
      p sl
      case @options[:verbose]
      when 1
        Hexdump.dump(sl.raw_data)
      when 2
        Hexdump.dump(sl.decoded_bytes)
      when 3..999
        Hexdump.dump(sl.raw_data)
        Hexdump.dump(sl.decoded_bytes)
        puts
      end
    end
  end

  def palette
    if @img.palette
      pp @img.palette
      Hexdump.dump @img.palette.data, :width => 6*3
    end
  end
end
