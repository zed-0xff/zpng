#!/usr/bin/env ruby
require 'zlib'
require 'stringio'
require 'rubygems'
require 'colorize'

require './pixel'
require './block'

# see alse http://github.com/wvanbergen/chunky_png/

module ZPNG

  class Chunk
    attr_accessor :size, :type, :data, :crc

    def self.from_stream io
      size, type = io.read(8).unpack('Na4')
      io.seek(-8,IO::SEEK_CUR)
      begin
        if const_defined?(type.upcase)
          klass = const_get(type.upcase)
          klass.new(io)
        else
          Chunk.new(io)
        end
      rescue NameError
        # invalid chunk type?
        Chunk.new(io)
      end
    end

    def initialize io
      @size, @type = io.read(8).unpack('Na4')
      @data        = io.read(size)
      @crc         = io.read(4).to_s.unpack('N').first
    end

    def inspect
      size = @size ? sprintf("%5d",@size) : sprintf("%5s","???")
      crc  = @crc  ? sprintf("%08x",@crc) : sprintf("%8s","???")
      type = @type.to_s.gsub(/[^0-9a-z]/i){ |x| sprintf("\\x%02X",x.ord) }
      sprintf("#<ZPNG::Chunk  %4s size=%s, crc=%s >", type, size, crc)
    end

    def crc_ok?
      expected_crc = Zlib.crc32(data, Zlib.crc32(type))
      expected_crc == crc
    end

    class IHDR < Chunk
      attr_accessor :width, :height, :depth, :color, :compression, :filter, :interlace

      COLOR_GRAYSCALE  = 0  # Each pixel is a grayscale sample
      COLOR_RGB        = 2  # Each pixel is an R,G,B triple.
      COLOR_PALETTE    = 3  # Each pixel is a palette index; a PLTE chunk must appear.
      COLOR_GRAY_ALPHA = 4  # Each pixel is a grayscale sample, followed by an alpha sample.
      COLOR_RGBA       = 6  # Each pixel is an R,G,B triple, followed by an alpha sample.

      SAMPLES_PER_COLOR = {
        COLOR_GRAYSCALE  => 1,
        COLOR_RGB        => 3,
        COLOR_PALETTE    => 1,
        COLOR_GRAY_ALPHA => 2,
        COLOR_RGBA       => 4
      }

      def initialize io
        super
        a = data.unpack('NNC5')
        @width = a[0]
        @height = a[1]
        @depth = a[2]
        @color = a[3]
        @compression = a[4]
        @filter = a[5]
        @interlace = a[6]
      end

      # bits per pixel
      def bpp
        SAMPLES_PER_COLOR[@color] * depth
      end

      def inspect
        super.sub(/ *>$/,'') + ", " +
          (instance_variables-[:@type, :@crc, :@data, :@size]).
          map{ |var| "#{var.to_s.tr('@','')}=#{instance_variable_get(var)}" }.
          join(", ") + ">"
      end
    end

    class PLTE < Chunk
    end

    class IEND < Chunk
    end
  end


  class ScanLine
    FILTER_NONE           = 0
    FILTER_SUB            = 1
    FILTER_UP             = 2
    FILTER_AVERAGE        = 3
    FILTER_PAETH          = 4

    attr_accessor :image, :idx, :filter, :offset

    def initialize image, idx
      @image,@idx = image,idx
      @bpp = image.hdr.bpp
      raise "[!] zero bpp" if @bpp == 0
      if @BPP = (@bpp%8 == 0) && (@bpp>>3)
        @offset = idx*(image.width*@BPP+1)
      else
        @offset = idx*(image.width*@bpp/8.0+1).ceil
      end
      @filter = image.imagedata[@offset].ord
      @offset += 1
    end

    def inspect
      "#<ZPNG::ScanLine " + (instance_variables-[:@image, :@decoded]).
          map{ |var| "#{var.to_s.tr('@','')}=#{instance_variable_get(var)}" }.
          join(", ") + ">"
    end

    def to_s
      @image.width.times.map do |i|
        px = decode_pixel(i)
        px.white?? ' ' : (px.black?? 'X' : '?')
      end.join
    end

    def [] x
      decode_pixel(x)
    end

    def decode_pixel x
      raw =
        if @BPP
          # 8, 16 or 32 bits per pixel
          decoded_bytes[x*@BPP, @BPP]
        else
          # 1, 2 or 4 bits per pixel
          decoded_bytes[x*@bpp/8, (@bpp/8.0).ceil]
        end

      r = g = b = nil
      case @bpp
      when 1
        r=g=b= (raw.ord & (1<<(7-(x%8)))) == 0 ? 0 : 0xff
      when 2
      when 4
      when 8
        r=g=b= raw.ord
      when 2
      when 16
      when 24
        r,g,b = raw.split('').map(&:ord)
      when 32
        r,g,b,a = raw.split('').map(&:ord)
      else raise "unexpected bpp #{@bpp}"
      end

      Pixel.new(r,g,b,a)
    end

    def decoded_bytes
      @decoded_bytes ||=
        begin
          # number of bytes per complete pixel, rounding up to one
          bpp1 = (@bpp/8.0).ceil

          # bytes in one scanline
          nbytes = (image.width*@bpp/8.0).ceil

          s = ''
          nbytes.times do |i|
            b0 = (i-bpp1) >= 0 ? s[i-bpp1] : nil
            s[i] = decode_byte(i, b0)
          end
#          print Hexdump.dump(s[0,16])
          s
        end
    end

    def decode_byte x, b0
      raw = @image.imagedata[@offset+x]

      unless raw
        STDERR.puts "[!] not enough bytes at pos #{x} of scanline #@idx".red
        raw = 0.chr
      end

      case @filter
      when FILTER_NONE  # 0
        raw

      when FILTER_SUB   # 1
        return raw unless b0
        ((raw.ord + b0.ord) & 0xff).chr

      when FILTER_UP    # 2
        return raw if @idx == 0
        prev = @image.scanlines[@idx-1].decoded_bytes[x]
        ((raw.ord + prev.ord) & 0xff).chr

      when FILTER_AVERAGE # 3
        prev = (b0 && b0.ord) || 0
        prior = (@idx > 0) ? @image.scanlines[@idx-1].decoded_bytes[x].ord : 0
        ((raw.ord + (prev + prior)/2) & 0xff).chr

      when FILTER_PAETH # 4
        pa = (b0 && b0.ord) || 0
        pb = (@idx > 0) ? @image.scanlines[@idx-1].decoded_bytes[x].ord : 0
        pc = (x > 0 && @idx > 0) ? @image.scanlines[@idx-1].decoded_bytes[x-1].ord : 0
        ((raw.ord + paeth_predictor(pa, pb, pc)) & 0xff).chr
      else
        raise "invalid ScanLine filter #{@filter}"
      end
    end

    def paeth_predictor a,b,c
      p = a + b - c
      pa = (p - a).abs
      pb = (p - b).abs
      pc = (p - c).abs
      (pa <= pb) ? (pa <= pc ? a : c) : (pb <= pc ? b : c)
    end
  end

  class Image
    attr_accessor :data, :header, :chunks, :imagedata, :palette
    alias :hdr :header

    PNG_HDR = "\x89PNG\x0d\x0a\x1a\x0a"

    def initialize h = {}
      if h[:file] && h[:file].is_a?(String)
        @data = File.read(h[:file]).force_encoding('binary')
      end

      d = data[0,PNG_HDR.size]
      if d != PNG_HDR
        puts "[!] first #{PNG_HDR.size} bytes must be #{PNG_HDR.inspect}, but got #{d.inspect}".red
      end

      io = StringIO.new(data)
      io.seek PNG_HDR.size
      @chunks = []
      while !io.eof?
        chunk = Chunk.from_stream(io)
        @chunks << chunk
        case chunk
        when Chunk::IHDR
          @header = chunk
        when Chunk::PLTE
          @palette = chunk
        when Chunk::IEND
          break
        end
      end
      unless io.eof?
        offset    = io.tell
        extradata = io.read
        puts "[?] #{extradata.size} bytes of extra data after image end (IEND), offset = 0x#{offset.to_s(16)}".red
      end
    end

    def dump
      @chunks.each do |chunk|
        puts "[.] #{chunk.inspect} #{chunk.crc_ok? ? 'CRC OK'.green : 'CRC ERROR'.red}"
      end
    end

    def width
      @header && @header.width
    end

    def height
      @header && @header.height
    end

    def imagedata
      if @header
        #raise "only RGB mode is supported for imagedata" if @header.color != Chunk::IHDR::COLOR_RGB
        raise "only non-interlaced mode is supported for imagedata" if @header.interlace != 0
      else
        puts "[?] no image header, assuming non-interlaced RGB".yellow
      end
      @imagedata ||=
        begin
          Zlib::Inflate.inflate(@chunks.find_all{ |c| c.type == "IDAT" }.map(&:data).join)
        end
    end

    def [] x, y
      scanlines[y][x]
    end

    def scanlines
      @scanlines ||=
        begin
          r = []
          height.times do |i|
            r << ScanLine.new(self,i)
          end
          r
        end
    end

    def to_s
      scanlines.map(&:to_s).join("\n")
    end

    def extract_block x,y=nil,w=nil,h=nil
      if x.is_a?(Hash)
        Block.new(self,x[:x], x[:y], x[:width], x[:height])
      else
        Block.new(self,x,y,w,h)
      end
    end

    def each_block bw,bh, &block
      0.upto(height/bh-1) do |by|
        0.upto(width/bw-1) do |bx|
          b = extract_block(bx*bw, by*bh, bw, bh)
          yield b
        end
      end
    end
  end
end

if $0 == __FILE__
  if ARGV.size == 0
    puts "gimme a png filename!"
  else
    img = ZPNG::Image.new(:file => ARGV[0])
    img.dump
    puts "[.] image size #{img.width}x#{img.height}"
    puts "[.] uncompressed imagedata size=#{img.imagedata.size}"
    puts "[.] palette =#{img.palette}"
#    puts "[.] imagedata: #{img.imagedata[0..30].split('').map{|x| sprintf("%02X",x.ord)}.join(' ')}"

    require 'hexdump'
    #Hexdump.dump(img.imagedata, :width => 6)
    require 'pp'
    pp img.scanlines[0..5]
#    puts Hexdump.dump(img.imagedata[0,60])
#    img.scanlines.each do |l|
#      puts l.to_s
#    end
    puts img.to_s
  end
end

