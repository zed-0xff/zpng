module ZPNG
  class Image
    attr_accessor :data, :header, :chunks, :scanlines, :imagedata, :palette
    alias :hdr :header

    PNG_HDR = "\x89PNG\x0d\x0a\x1a\x0a"

    def initialize x = nil
      if x
        if x[PNG_HDR]
          # raw image data
          @data = x
        else
          # filename
          @data = File.binread(x)
        end
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
        raise "only non-interlaced mode is supported for imagedata" if @header.interlace != 0
      else
        puts "[?] no image header, assuming non-interlaced RGB".yellow
      end
      @imagedata ||= Zlib::Inflate.inflate(@chunks.find_all{ |c| c.type == "IDAT" }.map(&:data).join)
    end

    def [] x, y
      scanlines[y][x]
    end

    def []= x, y, newpixel
      scanlines[y][x] = newpixel
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

    def export
      imagedata # fill @imagedata, if not already filled

      # delete redundant IDAT chunks
      first_idat = @chunks.find{ |c| c.type == 'IDAT' }
      @chunks.delete_if{ |c| c.type == 'IDAT' && c != first_idat }

      # fill first_idat @data with compressed imagedata
      first_idat.data = Zlib::Deflate.deflate(scanlines.map(&:export).join, 9)

      PNG_HDR + @chunks.map(&:export).join
    end
  end
end
