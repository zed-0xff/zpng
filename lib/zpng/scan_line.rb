#coding: binary
module ZPNG
  class ScanLine
    FILTER_NONE           = 0
    FILTER_SUB            = 1
    FILTER_UP             = 2
    FILTER_AVERAGE        = 3
    FILTER_PAETH          = 4

    attr_accessor :image, :idx, :filter, :offset, :bpp
    attr_writer :decoded_bytes

    def initialize image, idx, params={}
      @image,@idx = image,idx
      @bpp = image.hdr.bpp
      raise "[!] zero bpp" if @bpp == 0

      # Bytes Per Pixel, if bpp = 8, 16, 24, 32
      # NULL otherwise
      @BPP = (@bpp%8 == 0) && (@bpp>>3)

      if @image.new?
        @size = params[:size]
        @decoded_bytes = params[:decoded_bytes] || "\x00" * (size-1)
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
      @size ||=
        begin
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

    def []= x, color
      case image.hdr.color
      when COLOR_INDEXED                # ALLOWED_DEPTHS: 1, 2, 4, 8
        color_idx = image.palette.find_or_add(color)
        raise "no color #{color.inspect} in palette" unless color_idx

        mask  = 2**@bpp-1
        shift = 8-(x%(8/@bpp)+1)*@bpp
        raise "invalid shift #{shift}" if shift < 0 || shift > 7

        pos = x*@bpp/8
        b = decoded_bytes[pos].ord
        b = (b & (0xff-(mask<<shift))) | ((color_idx & mask) << shift)
        decoded_bytes[pos] = b.chr
        # TODO: transparency in TRNS

      when COLOR_GRAYSCALE              # ALLOWED_DEPTHS: 1, 2, 4, 8, 16
        raw = color.to_depth(@bpp).to_grayscale
        pos = x*@bpp/8
        if @bpp == 16
          decoded_bytes[pos,2] = [raw].pack('n')
        else
          mask  = 2**@bpp-1
          shift = 8-(x%(8/@bpp)+1)*@bpp
          raise "invalid shift #{shift}" if shift < 0 || shift > 7
          b = decoded_bytes[pos].ord
          b = (b & (0xff-(mask<<shift))) | ((raw & mask) << shift)
          decoded_bytes[pos] = b.chr
        end
        # TODO: transparency in TRNS

      when COLOR_RGB                    # ALLOWED_DEPTHS: 8, 16
        case @bpp
        when 24; decoded_bytes[x*3,3] = color.to_depth(8).to_a.pack('C3')
        when 48; decoded_bytes[x*6,6] = color.to_depth(16).to_a.pack('n3')
        else raise "unexpected bpp #@bpp"
        end
        # TODO: transparency in TRNS

      when COLOR_GRAY_ALPHA             # ALLOWED_DEPTHS: 8, 16
        case @bpp
        when 16; decoded_bytes[x*2,2] = color.to_depth(8).to_gray_alpha.pack('C2')
        when 32; decoded_bytes[x*4,4] = color.to_depth(16).to_gray_alpha.pack('n2')
        else raise "unexpected bpp #@bpp"
        end

      when COLOR_RGBA                   # ALLOWED_DEPTHS: 8, 16
        case @bpp
        when 32; decoded_bytes[x*4,4] = color.to_depth(8).to_a.pack('C4')
        when 64; decoded_bytes[x*8,8] = color.to_depth(16).to_a.pack('n4')
        else raise "unexpected bpp #@bpp"
        end

      else
        raise "unexpected color mode #{image.hdr.color}"

      end # case image.hdr.color
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

      case image.hdr.color
      when COLOR_INDEXED                # ALLOWED_DEPTHS: 1, 2, 4, 8
        mask  = 2**@bpp-1
        shift = 8-(x%(8/@bpp)+1)*@bpp
        raise "invalid shift #{shift}" if shift < 0 || shift > 7
        idx = (raw.ord >> shift) & mask
        if image.trns
          # transparency from tRNS chunk
          # For color type 3 (indexed color), the tRNS chunk contains a series of one-byte alpha values,
          # corresponding to entries in the PLTE chunk:
          #
          #   Alpha for palette index 0:  1 byte
          #   Alpha for palette index 1:  1 byte
          #   ...
          #
          color = image.palette[idx].dup
          if color.alpha = image.trns.data[idx]
            # if it's not NULL - convert it from char to int,
            # otherwise it means fully opaque color, as well as NULL alpha in ZPNG::Color
            color.alpha = color.alpha.ord
          end
          return color
        else
          # no transparency
          return image.palette[idx]
        end

      when COLOR_GRAYSCALE              # ALLOWED_DEPTHS: 1, 2, 4, 8, 16
        c = if @bpp == 16
              raw.unpack('n')[0]
            else
              mask  = 2**@bpp-1
              shift = 8-(x%(8/@bpp)+1)*@bpp
              raise "invalid shift #{shift}" if shift < 0 || shift > 7
              (raw.ord >> shift) & mask
            end

        color = Color.from_grayscale(c, :depth => @bpp) # only in this color mode depth == bpp
        color.alpha = image._alpha_color(color)
        return color

      when COLOR_RGB                    # ALLOWED_DEPTHS: 8, 16
        color =
          case @bpp
          when 24                     # RGB  8 bits per sample = 24bpp
            # color_class is for (limited) BMP support
            image.color_class.new(*raw.unpack('C3'))
          when 48                     # RGB 16 bits per sample = 48bpp
            Color.new(*raw.unpack('n3'), :depth => 16)
          else raise "COLOR_RGB unexpected bpp #@bpp"
          end

        color.alpha = image._alpha_color(color)
        return color

      when COLOR_GRAY_ALPHA             # ALLOWED_DEPTHS: 8, 16
        case @bpp
        when 16                         #  8-bit grayscale +  8-bit alpha
          return Color.from_grayscale(*raw.unpack('C2'))
        when 32                         # 16-bit grayscale + 16-bit alpha
          return Color.from_grayscale(*raw.unpack('n2'), :depth => 16)
        else raise "COLOR_GRAY_ALPHA unexpected bpp #@bpp"
        end

      when COLOR_RGBA                   # ALLOWED_DEPTHS: 8, 16
        case @bpp
        when 32                         # RGBA  8-bit/sample
          # color_class is for (limited) BMP support
          return image.color_class.new(*raw.unpack('C4'))
        when 64                         # RGBA 16-bit/sample
          return Color.new(*raw.unpack('n4'), :depth => 16 )
        else raise "COLOR_RGBA unexpected bpp #@bpp"
        end

      else
        raise "unexpected color mode #{image.hdr.color}"

      end # case img.hdr.color
    end

    def decoded_bytes
      #raise if caller.size > 50
      @decoded_bytes ||=
        begin
          imagedata = @image.imagedata

          # number of bytes per complete pixel, rounding up to one
          bpp1 = (@bpp/8.0).ceil

          case @filter

          when FILTER_NONE    # 0
            s = imagedata[@offset+1, size-1]

          when FILTER_SUB     # 1
            s = "\x00" * size
            s[0,bpp1] = imagedata[@offset+1,bpp1]
            bpp1.upto(size-2) do |i|
              s.setbyte(i, imagedata.getbyte(@offset+i+1) + s.getbyte(i-bpp1))
            end

          when FILTER_UP      # 2
            s = "\x00" * size
            0.upto(size-2) do |i|
              s.setbyte(i, imagedata.getbyte(@offset+i+1) + prev_scanline_byte(i))
            end

          when FILTER_AVERAGE # 3
            s = "\x00" * size
            0.upto(bpp1-1) do |i|
              s.setbyte(i, imagedata.getbyte(@offset+i+1) + prev_scanline_byte(i)/2)
            end
            bpp1.upto(size-2) do |i|
              s.setbyte(i,
                imagedata.getbyte(@offset+i+1) + (s.getbyte(i-bpp1) + prev_scanline_byte(i))/2
              )
            end

          when FILTER_PAETH   # 4
            s = "\x00" * size
            0.upto(bpp1-1) do |i|
              s.setbyte(i, imagedata.getbyte(@offset+i+1) + prev_scanline_byte(i))
            end
            bpp1.upto(size-2) do |i|
              s.setbyte(i,
                imagedata.getbyte(@offset+i+1) +
                paeth_predictor(s.getbyte(i-bpp1), prev_scanline_byte(i), prev_scanline_byte(i-bpp1))
              )
            end

          else raise "invalid ScanLine filter #{@filter}"
          end

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

    module InterlacedMixIn
      def prev_scanline_byte x
        # When the image is interlaced, each pass of the interlace pattern is
        # treated as an independent image for filtering purposes
        image.adam7.pass_start?(@idx) ? 0 : image.scanlines[@idx-1].decoded_bytes.getbyte(x)
      end
    end

    module NotFirstLineMixIn
      def prev_scanline_byte x
        image.scanlines[@idx-1].decoded_bytes.getbyte(x)
      end
    end

    module FirstLineMixIn
      def prev_scanline_byte x
        0
      end
    end

    def prev_scanline_byte x
      # defining instance methods gives 10-15% speed boost
      if image.interlaced?
        extend InterlacedMixIn
      elsif @idx > 0
        extend NotFirstLineMixIn
      else
        extend FirstLineMixIn
      end
      # call newly created method
      prev_scanline_byte x
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
      @size = nil # unmemoize self size b/c it's changed after crop
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
