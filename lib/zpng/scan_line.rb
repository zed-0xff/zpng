#coding: binary
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

      # Bytes Per Pixel, if bpp = 8, 16, 24, 32
      # NULL otherwise
      @BPP = (@bpp%8 == 0) && (@bpp>>3)

      if @image.new?
        @decoded_bytes = "\x00" * (size-1)
      else
        @offset = idx*size
        @filter = image.imagedata[@offset].ord
        @offset += 1
      end
    end

    # total scanline size in bytes, INCLUDING leading 'filter' byte
    def size
      if @BPP
        image.width*@BPP+1
      else
        (image.width*@bpp/8.0+1).ceil
      end
    end

    def inspect
      "#<ZPNG::ScanLine " + (instance_variables-[:@image, :@decoded]).
          map{ |var| "#{var.to_s.tr('@','')}=#{instance_variable_get(var)}" }.
          join(", ") + ">"
    end

    def to_s h={}
      white   = h[:white]   || ' '
      black   = h[:black]   || '#'
      unknown = h[:unknown] || '?'

      @image.width.times.map do |i|
        px = decode_pixel(i)
        px.white?? white : (px.black?? black : unknown)
      end.join
    end

    def [] x
      decode_pixel(x)
    end

    def []= x, newcolor
      case @bpp
      when 1
        flag =
          if image.hdr.palette_used?
            idx = image.palette.index(newcolor)
            raise "no color #{newcolor.inspect} in palette" unless idx
            idx == 1
          else
            if newcolor.white?
              true
            elsif newcolor.black?
              false
            else
              raise "1bpp pixel can only be WHITE or BLACK, got #{newcolor.inspect}"
            end
          end
        if flag
          # turn pixel on
          decoded_bytes[x/8] = (decoded_bytes[x/8].ord | (1<<(7-(x%8)))).chr
        else
          # turn pixel off
          decoded_bytes[x/8] = (decoded_bytes[x/8].ord & (0xff-(1<<(7-(x%8))))).chr
        end
      when 8
        if image.hdr.palette_used?
          decoded_bytes[x] = (image.palette.index(newcolor)).chr
        else
          decoded_bytes[x] = ((newcolor.r + newcolor.g + newcolor.b)/3).chr
        end
      when 16
        if image.hdr.palette_used? && image.hdr.alpha_used?
          decoded_bytes[x*2] = (image.palette.index(newcolor)).chr
          decoded_bytes[x*2+1] = (newcolor.alpha || 0xff).chr
        elsif image.hdr.grayscale? && image.hdr.alpha_used?
          decoded_bytes[x*2] = newcolor.to_grayscale.chr
          decoded_bytes[x*2+1] = (newcolor.alpha || 0xff).chr
        else
          raise "unexpected colormode #{image.hdr.inspect}"
        end
      when 24
        decoded_bytes[x*3,3] = [newcolor.r, newcolor.g, newcolor.b].map(&:chr).join
      when 32
        decoded_bytes[x*4,4] = [newcolor.r, newcolor.g, newcolor.b, newcolor.a].map(&:chr).join
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

      r = g = b = a = nil

      colormode = image.hdr.color

      if image.hdr.palette_used?
        idx =
          case @bpp
          when 1
            # needed for palette
            (raw.ord & (1<<(7-(x%8)))) == 0 ? 0 : 1
          when 4
            x%2 == 0 ? (raw.ord&0x0f) : (raw.ord >> 4)
          when 8
            raw.ord
          when 16
            raw[0].ord
          else raise "unexpected bpp #{@bpp}"
          end

        return image.palette[idx]
      end

      case @bpp
      when 1
        r=g=b= (raw.ord & (1<<(7-(x%8)))) == 0 ? 0 : 0xff
      when 8
        if colormode == ZPNG::Chunk::IHDR::COLOR_GRAYSCALE
          r=g=b= raw.ord
        else
          raise "unexpected colormode #{colormode} for bpp #{@bpp}"
        end
      when 16
        if colormode == ZPNG::Chunk::IHDR::COLOR_GRAY_ALPHA
          r=g=b= raw[0].ord
          a = raw[1].ord
        else
          raise "unexpected colormode #{colormode} for bpp #{@bpp}"
        end
      when 24
        r,g,b = raw.split('').map(&:ord)
      when 32
        r,g,b,a = raw.split('').map(&:ord)
      else raise "unexpected bpp #{@bpp}"
      end

      Color.new(r,g,b,a)
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
            s[i] = decode_byte(i, b0, bpp1)
          end
#          print Hexdump.dump(s[0,16])
          s
        end
    end

    def decode!
      decoded_bytes
      true
    end

    def decode_byte x, b0, bpp1
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
        pc = (b0 && @idx > 0) ? @image.scanlines[@idx-1].decoded_bytes[x-bpp1].ord : 0
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
