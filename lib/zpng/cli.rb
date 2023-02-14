require 'zpng'
require 'optparse'
require 'pp'

module ZPNG
  class CLI
    include Hexdump

    DEFAULT_ACTIONS = %w'info metadata chunks'

    def initialize argv = ARGV
      # hack #1: allow --chunk as well as --chunks
      @argv = argv.map{ |x| x.sub(/^--chunks?/,'--chunk(s)') }

      # hack #2: allow --chunk(s) followed by a non-number, like "zpng --chunks fname.png"
      @argv.each_cons(2) do |a,b|
        if a == "--chunk(s)" && b !~ /^\d+$/
          a<<"=-1"
        end
      end
    end

    def run
      @actions = []
      @options = { :verbose => 0 }
      optparser = OptionParser.new do |opts|
        opts.banner = "Usage: zpng [options] filename.png"
        opts.separator ""

        opts.on("-i", "--info", "General image info (default)"){ @actions << :info }
        opts.on("-c", "--chunk(s) [ID]", Integer, "Show chunks (default) or single chunk by its #") do |id|
          id = nil if id == -1
          @actions << [:chunks, id]
        end
        opts.on("-m", "--metadata", "Show image metadata, if any (default)"){ @actions << :metadata }

        opts.separator ""
        opts.on("-S", "--scanlines", "Show scanlines info"){ @actions << :scanlines }
        opts.on("-P", "--palette", "Show palette"){ @actions << :palette }
        opts.on(      "--colors", "Show colors used"){ @actions << :colors }

        opts.on "-E", "--extract-chunk ID", Integer, "extract a single chunk" do |id|
          @actions << [:extract_chunk, id]
        end
        opts.on "-D", "--imagedata", "dump unpacked Image Data (IDAT) chunk(s) to stdout" do
          @actions << :unpack_imagedata
        end

        opts.separator ""
        opts.on "-C", "--crop GEOMETRY", "crop image, {WIDTH}x{HEIGHT}+{X}+{Y},",
        "puts results on stdout unless --ascii given" do |x|
          @actions << [:crop, x]
        end

        opts.on "-R", "--rebuild NEW_FILENAME", "rebuild image, useful in restoring borked images" do |x|
          @actions << [:rebuild, x]
        end

        opts.separator ""
        opts.on "-A", '--ascii', 'Try to convert image to ASCII (works best with monochrome images)' do
          @actions << :ascii
        end
        opts.on '--ascii-string STRING', 'Use specific string to map pixels to ASCII characters' do |x|
          @options[:ascii_string] = x
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

        opts.separator ""
        opts.on "-v", "--verbose", "Run verbosely (can be used multiple times)" do |v|
          @options[:verbose] += 1
        end
        opts.on "-q", "--quiet", "Silent any warnings (can be used multiple times)" do |v|
          @options[:verbose] -= 1
        end
        opts.on "-I", "--console", "opens IRB console with specified image loaded" do |v|
          @actions << :console
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
        @fname = fname

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

    def rebuild fname
      File.binwrite(fname, @img.export)
    end

    def load_file fname
      @img = Image.load fname, :verbose => @options[:verbose]+1
    end

    def metadata
      return if @img.metadata.empty?
      puts "[.] metadata:"
      @img.metadata.each do |k,v,h|
        if @options[:verbose] < 2
          if k.size > 512
            puts "[?] key too long (#{k.size}), truncated to 512 chars".yellow
            k = k[0,512] + "..."
          end
          if v.size > 512
            puts "[?] value too long (#{v.size}), truncated to 512 chars".yellow
            v = v[0,512] + "..."
          end
        end
        if h.keys.sort == [:keyword, :text]
          v.gsub!(/[\n\r]+/, "\n"+" "*19)
          printf "    %-12s : %s\n", k, v.gray
        else
          printf "    %s (%s: %s):", k, h[:language], h[:translated_keyword]
          v.gsub!(/[\n\r]+/, "\n"+" "*19)
          printf "\n%s%s\n", " "*19, v.gray
        end
      end
      puts
    end

    def info
      color = %w'COLOR_GRAYSCALE COLOR_RGB COLOR_INDEXED COLOR_GRAY_ALPHA COLOR_RGBA'.find do |k|
        @img.hdr.color == ZPNG.const_get(k)
      end
      puts "[.] image size #{@img.width || '?'}x#{@img.height || '?'}, #{@img.bpp || '?'}bpp, #{color}"
      puts "[.] palette = #{@img.palette}" if @img.palette
      puts "[.] uncompressed imagedata size = #{@img.imagedata_size || '?'} bytes"
      _conditional_hexdump(@img.imagedata, 3) if @options[:verbose] > 0
    end

    def _conditional_hexdump data, v2 = 2
      return unless data

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

    def chunks idx=nil
      max_type_len = 0
      unless idx
        max_type_len = @img.chunks.map{ |x| x.type.to_s.size }.max
      end

      @img.chunks.each do |chunk|
        next if idx && chunk.idx != idx
        colored_type = chunk.type.ljust(max_type_len).magenta
        colored_crc =
          if chunk.crc == :no_crc # hack for BMP chunks (they have no CRC)
            ''
          elsif chunk.crc_ok?
            'CRC OK'.green
          else
            'CRC ERROR'.red
          end
        puts "[.] #{chunk.inspect(@options[:verbose]).sub(chunk.type, colored_type)} #{colored_crc}"

        if @options[:verbose] >= 3
          _conditional_hexdump(chunk.export(fix_crc: false))
        else
          _conditional_hexdump(chunk.data)
        end
      end
    end

    def ascii
      @img.height.times do |y|
        @img.width.times do |x|
          c = @img[x,y].to_ascii *[@options[:ascii_string]].compact
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
          hexdump(sl.raw_data) if sl.raw_data
        when 2
          hexdump(sl.decoded_bytes)
        when 3..999
          hexdump(sl.raw_data) if sl.raw_data
          hexdump(sl.decoded_bytes)
          puts
        end
      end
    end

    def palette
      if @img.palette
        pp @img.palette
        if @img.format == :bmp
          hexdump(@img.palette.data, :width => 4, :show_offset => false) do |row, offset|
            row.insert(0,"  color %4s:  " % "##{(offset/4)}")
          end
        else
          hexdump(@img.palette.data, :width => 3, :show_offset => false) do |row, offset|
            row.insert(0,"  color %4s:  " % "##{(offset/3)}")
          end
        end
      end
    end

    def colors
      h=Hash.new(0)
      h2=Hash.new{ |k,v| k[v] = [] }
      @img.each_pixel do |c,x,y|
        h[c] += 1
        if h[c] < 6
          h2[c] << [x,y]
        end
      end

      xlen = @img.width.to_s.size
      ylen = @img.height.to_s.size

      h.sort_by{ |c,n| [n] + h2[c].first.reverse }.each do |c,n|
        printf "%6d : %s : ", n, c.inspect
        h2[c].each_with_index do |a,idx|
          print ";" if idx > 0
          if idx >= 4
            print " ..."
            break
          end
          printf " %*d,%*d", xlen, a[0], ylen, a[1]
        end
        puts
      end
    end

    def console
      ARGV.clear # clear ARGV so IRB is not confused
      require 'irb'
      m0 = IRB.method(:setup)
      img = @img

      # override IRB.setup, called from IRB.start
      IRB.define_singleton_method :setup do |*args|
        m0.call *args
        conf[:IRB_RC] = Proc.new do |context|
          context.main.instance_variable_set '@img', img
          context.main.define_singleton_method(:img){ @img }
        end
      end

      puts "[.] img = ZPNG::Image.load(#{@fname.inspect})".gray
      IRB.start
    end
  end
end
