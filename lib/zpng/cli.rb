require 'zpng'
require 'optparse'
require 'pp'

module ZPNG
  class CLI
    include Hexdump

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
        if argv.size > 1 && @options[:verbose] >= 0
          puts if idx > 0
          puts "[.] #{fname}".color(:green)
        end
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
          when Chunk::ZTXT
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
      @img = Image.load fname
    end

    def info
      puts "[.] image size #{@img.width || '?'}x#{@img.height || '?'}, bpp=#{@img.bpp}"
      puts "[.] palette = #{@img.palette}" if @img.palette
      puts "[.] uncompressed imagedata size = #{@img.imagedata.size} bytes"
      _conditional_hexdump @img.imagedata, 3
    end

    def _conditional_hexdump data, v2 = 2
      if @options[:verbose] <= 0
        # do nothing
      elsif @options[:verbose] < v2
        sz = 0x20
        print Hexdump.dump(data[0,sz],
                          :show_offset => false,
                          :tail => data.size > sz ? " + #{data.size-sz} bytes\n" : "\n"
                         ){ |row| row.insert(0,"    ") }.gray
        puts

      elsif @options[:verbose] >= v2
        print Hexdump.dump(data){ |row| row.insert(0,"    ") }.gray
        puts
      end
    end

    def chunks
      @img.chunks.each do |chunk|
        colored_type = chunk.type.magenta
        colored_crc  = chunk.crc_ok? ? 'CRC OK'.green : 'CRC ERROR'.red
        puts "[.] #{chunk.inspect.sub(chunk.type, colored_type)} #{colored_crc}"

        _conditional_hexdump(chunk.data) unless chunk.size == 0
      end
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
          print spc.background(@img[x,y].to_ansi)
        end
        puts
      end
    end

    def ansi256
      require 'rainbow'
      spc = @options[:wide] ? "  " : " "
      @img.height.times do |y|
        @img.width.times do |x|
          print spc.background(@img[x,y].to_html)
        end
        puts
      end
    end

    def scanlines
      @img.scanlines.each do |sl|
        p sl
        case @options[:verbose]
        when 1
          hexdump(sl.raw_data)
        when 2
          hexdump(sl.decoded_bytes)
        when 3..999
          hexdump(sl.raw_data)
          hexdump(sl.decoded_bytes)
          puts
        end
      end
    end

    def palette
      if @img.palette
        pp @img.palette
        hexdump(@img.palette.data, :width => 3, :show_offset => false) do |row, offset|
          row.insert(0,"  color %4s:  " % "##{(offset/3)}")
        end
      end
    end
  end
end
