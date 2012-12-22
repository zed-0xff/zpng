#coding: binary
module ZPNG
  class ScanLine
    FILTER_NONE           = 0
    FILTER_SUB            = 1
    FILTER_UP             = 2
    FILTER_AVERAGE        = 3
    FILTER_PAETH          = 4

    attr_accessor :image, :idx, :filter, :offset, :bpp

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
        @offset = idx*size
      else
        @offset =
          if image.interlaced?
            image.adam7.scanline_offset(idx)
          else
            idx*size
          end
        if @filter = image.imagedata[@offset]
          @filter = @filter.ord
        else
          STDERR.puts "[!] #{self.class}: ##@idx: no data at pos 0, scanline dropped".red
        end
      end
    end

    # ScanLine is BAD if it has no filter
    def bad?
      !@filter
    end

    # total scanline size in bytes, INCLUDING leading 'filter' byte
    def size
      w =
        if image.interlaced?
          image.adam7.scanline_width(idx)
        else
          image.width
        end
      if @BPP
        w*@BPP+1
      else
        (w*@bpp/8.0+1).ceil
      end
    end

    def inspect
      if image.interlaced?
        "#<ZPNG::ScanLine idx=%-2d offset=%-3d width=%-2d size=%-2d bpp=%d filter=%d>" %
          [idx, offset, image.adam7.scanline_width(idx), size, bpp, filter]
      else
        "#<ZPNG::ScanLine idx=%-2d offset=%-3d size=%-2d bpp=%d filter=%d>" %
          [idx, offset, size, bpp, filter]
      end
    end

    def to_ascii *args
      @image.width.times.map do |i|
        decode_pixel(i).to_ascii(*args)
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
          if image.alpha_used?
            raw.unpack 'C2'
          else
            # 16-bit grayscale
            raw.unpack 'n'
          end
        when 24
          # RGB
          return Color.new(*raw.unpack('C3'))
        when 32
          # RGBA
          return Color.new(*raw.unpack('C4'))
        when 48
          # RGB 16 bits per sample
          return Color.new(*raw.unpack('n3'), :depth => 16)
        when 64
          # RGB 16 bits per sample + 16-bit alpha
          return Color.new(*raw.unpack('n4'), :depth => 16, :alpha_depth => 16)
        else
          raise "unexpected bpp #{@bpp}"
        end

      if image.grayscale?
        Color.from_grayscale(color,
                             :alpha => alpha,
                             :depth => image.hdr.depth,
                             :alpha_depth => image.alpha_used? ? image.hdr.depth : 0
                            )
      elsif image.palette
        color = image.palette[color]
        color.alpha = alpha
        color
      else
        raise "cannot decode color"
      end
    end

    def decoded_bytes
      #raise if caller.size > 50
      @decoded_bytes ||=
        begin
          # number of bytes per complete pixel, rounding up to one
          bpp1 = (@bpp/8.0).ceil

          s = ''
          (size-1).times do |i|
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

    def raw_data
      @offset ? @image.imagedata[@offset, size] : ''
    end

    private
    def decode_byte x, b0, bpp1
      raw = @image.imagedata[@offset+x+1]

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
