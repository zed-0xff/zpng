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
        @filter = FILTER_NONE
      else
        @offset = idx*size
        if @filter = image.imagedata[@offset]
          @filter = @filter.ord
        else
          STDERR.puts "[!] #{self.class}: ##@idx: no data at pos 0, scanline dropped".red
        end
        @offset += 1
      end
    end

    # ScanLine is BAD if it has no filter
    def bad?
      !@filter
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
      "#<ZPNG::ScanLine " + (instance_variables-[:@image, :@decoded, :@BPP]).
          map{ |var| "#{var.to_s.tr('@','')}=#{instance_variable_get(var)}" }.
          join(", ") + ">"
    end

    def to_s h={}
      white   = h[:white]   || ' '
      black   = h[:black]   || '#'
      unknown = h[:unknown] || '?'

      @image.width.times.map do |i|
        px = decode_pixel(i)
#        printf "[d] %08x %s %s\n", px.to_i, px.inspect, px.to_s unless px.black?
        px.white?? white : (px.black?? black : unknown)
      end.join
    end

    def [] x
      decode_pixel(x)
    end

    def []= x, newcolor
      if image.hdr.palette_used?
        color_idx = image.palette.find_or_add(newcolor)
        raise "no color #{newcolor.inspect} in palette" unless color_idx
      elsif image.grayscale?
        color_idx = newcolor.to_grayscale
      end

      case @bpp
      when 1,2,4
        pos = x*@bpp/8
        b = decoded_bytes[pos].ord
        mask  = 2**@bpp-1
        shift = 8-(x%(8/@bpp)+1)*@bpp
        raise "invalid shift #{shift}" if shift < 0 || shift > 7

#        printf "[d] %s x=%2d bpp=%d pos=%d mask=%08b shift=%d decoded_bytes=#{decoded_bytes.inspect}\n", self.to_s, x, @bpp, pos, mask, shift

        b = (b & (0xff-(mask<<shift))) | ((color_idx & mask) << shift)
        decoded_bytes[pos] = b.chr

      when 8
        if image.hdr.palette_used?
          decoded_bytes[x] = color_idx.chr
        else
          decoded_bytes[x] = ((newcolor.r + newcolor.g + newcolor.b)/3).chr
        end
      when 16
        if image.hdr.palette_used? && image.hdr.alpha_used?
          decoded_bytes[x*2] = color_idx.chr
          decoded_bytes[x*2+1] = (newcolor.alpha || 0xff).chr
        elsif image.grayscale? && image.hdr.alpha_used?
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
          decoded_bytes[x*@bpp/8]
        end

      color, alpha =
        case @bpp
        when 1,2,4
          mask  = 2**@bpp-1
          shift = 8-(x%(8/@bpp)+1)*@bpp
          raise "invalid shift #{shift}" if shift < 0 || shift > 7
          [(raw.ord >> shift) & mask, nil]
        when 8
          [raw.ord, nil]
        when 16
          raw.unpack 'C2'
        when 24
          # RGB
          return Color.new(*raw.unpack('C3'))
        when 32
          # RGBA
          return Color.new(*raw.unpack('C4'))
        else
          raise "unexpected bpp #{@bpp}"
        end

      if image.grayscale?
        if [1,2,4].include?(@bpp)
          #color should be extended to a 8-bit range
          if color%2 == 0
            color <<= (8-@bpp)
          else
            (8-@bpp).times{ color = color*2 + 1 }
          end
        end
        Color.from_grayscale(color, alpha)
      elsif image.palette
        color = image.palette[color]
        color.alpha = alpha
        color
      else
        raise "cannot decode color"
      end
    end

    def decoded_bytes
      raise if caller.size > 50
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

    private
    def decode_byte x, b0, bpp1
      raw = @image.imagedata[@offset+x]

      unless raw
        STDERR.puts "[!] #{self.class}: ##@idx: no data at pos #{x}".red
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

    public
    def crop! x, w
      if @BPP
        # great, crop is byte-aligned! :)
        decoded_bytes[0,x*@BPP]   = ''
        decoded_bytes[w*@BPP..-1] = ''
      else
        # oh, no we have to shift bits in a whole line :(
        case @bpp
        when 1,2,4
          cut_bits_head = @bpp*x
          if cut_bits_head > 8
            # cut whole head bytes
            decoded_bytes[0,cut_bits_head/8] = ''
          end
          cut_bits_head %= 8
          if cut_bits_head > 0
            # bit-shift all remaining bytes
            (w*@bpp/8.0).ceil.times do |i|
              decoded_bytes[i] = ((
                (decoded_bytes[i].ord<<cut_bits_head) |
                (decoded_bytes[i+1].ord>>(8-cut_bits_head))
              ) & 0xff).chr
            end
          end

          new_width_bits = w*@bpp
          diff = decoded_bytes.size*8 - new_width_bits
          raise if diff < 0
          if diff > 8
            # cut whole tail bytes
            decoded_bytes[(new_width_bits/8.0).ceil..-1] = ''
          end
          diff %= 8
          if diff > 0
            # zero tail bits of last byte
            decoded_bytes[-1] = (decoded_bytes[-1].ord & (0xff-(2**diff)+1)).chr
          end

        else
          raise "unexpected bpp=#@bpp"
        end
      end
    end

    def export
      # we export in FILTER_NONE mode
      FILTER_NONE.chr + decoded_bytes
    end
  end
end