module ZPNG
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

    def []= x, newpixel
      case @bpp
      when 1
        if newpixel.white?
          # turn pixel on
          decoded_bytes[x/8] = (decoded_bytes[x/8].ord | (1<<(7-(x%8)))).chr
        elsif newpixel.black?
          # turn pixel off
          decoded_bytes[x/8] = (decoded_bytes[x/8].ord & (0xff-(1<<(7-(x%8))))).chr
        else
          raise "1bpp pixel can only be WHITE or BLACK, got #{newpixel.inspect}"
        end
      when 8
        decoded_bytes[x] = ((newpixel.r + newpixel.g + newpixel.b)/3).chr
      when 24
        decoded_bytes[x*3,3] = [newpixel.r, newpixel.g, newpixel.b].map(&:chr).join
      when 32
        decoded_bytes[x*4,4] = [newpixel.r, newpixel.g, newpixel.b, newpixel.a].map(&:chr).join
      else raise "unsupported bpp #{@bpp}"
      end
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

    def export
      # we export in FILTER_NONE mode
      "\x00" + decoded_bytes
    end
  end
end
