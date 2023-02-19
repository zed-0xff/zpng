#coding: binary

require 'set'

module ZPNG
  class ScanLine
    FILTER_NONE           = 0
    FILTER_SUB            = 1
    FILTER_UP             = 2
    FILTER_AVERAGE        = 3
    FILTER_PAETH          = 4

    VALID_FILTERS = FILTER_NONE..FILTER_PAETH

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
        @offset = params[:offset] || idx*size
      else
        @offset =
          if image.interlaced?
            image.adam7.scanline_offset(idx)
          else
            idx*size
          end
        if @filter = image.imagedata[@offset]
          @filter = @filter.ord
        elsif @image.verbose >= -1
          STDERR.puts "[!] #{self.class}: ##@idx: no data at pos 0, scanline dropped".red
        end
      end
      @errors = Set.new
    end

    # ScanLine is BAD if it has no filter
    def bad?
      !@filter
    end

    def valid_filter?
      VALID_FILTERS.include?(@filter)
    end

    # total scanline size in bytes, INCLUDING leading 'filter' byte
    def size
      @size ||=
        begin
          if @BPP
            width*@BPP+1
          else
            (width*@bpp/8.0+1).ceil
          end
        end
    end

    # scanline width in pixels
    def width
      if image.interlaced?
        image.adam7.scanline_width(idx)
      else
        image.width
      end
    end

    def inspect
      if image.interlaced?
        "#<ZPNG::ScanLine idx=%-2d offset=%-3d width=%-2d size=%-2d bpp=%d filter=%d>" %
          [idx, offset, width, size, bpp, filter]
      else
        "#<ZPNG::ScanLine idx=%-2d offset=%-3d size=%-2d bpp=%d filter=%d>" %
          [idx, offset, size, bpp, filter]
      end
    end

    def to_ascii *args
      @image.width.times.map do |i|
        self[i].to_ascii(*args)
      end.join
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
        b = decoded_bytes.getbyte(pos)
        b = (b & (0xff-(mask<<shift))) | ((color_idx & mask) << shift)
        decoded_bytes.setbyte(pos, b)
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

    def get_raw x
      return nil if @bpp > 8 || image.hdr.color != COLOR_INDEXED

      raw =
        if @BPP
          # 8, 16, 24, 32, 48 bits per pixel
          decoded_bytes[x*@BPP, @BPP]
        else
          # 1, 2 or 4 bits per pixel
          decoded_bytes[x*@bpp/8]
        end

      mask  = 2**@bpp-1
      shift = 8-(x%(8/@bpp)+1)*@bpp
      raise "invalid shift #{shift}" if shift < 0 || shift > 7
      idx = (raw.ord >> shift) & mask
    end

    def [] x
      raw =
        if @BPP
          # 8, 16, 24, 32, 48 bits per pixel
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
        color = image.palette[idx]
        unless color
          if !@errors.include?(x) && @image.verbose >= -1
            # prevent same error popping up multiple times, f.ex. in zsteg analysis
            @errors << x
            if (32..127).include?(idx)
              msg = '[!] %s: color #%-3d ("%c") at x=%d y=%d is out of palette!'.red % [self.class, idx, idx, x, @idx]
            else
              msg = "[!] %s: color #%-3d at x=%d y=%d is out of palette!".red % [self.class, idx, x, @idx]
            end
            STDERR.puts msg
          end
          color = Color.new(0,0,0)
        end
        if image.trns
          # transparency from tRNS chunk
          # For color type 3 (indexed color), the tRNS chunk contains a series of one-byte alpha values,
          # corresponding to entries in the PLTE chunk:
          #
          #   Alpha for palette index 0:  1 byte
          #   Alpha for palette index 1:  1 byte
          #   ...
          #
          if color.alpha = image.trns.data[idx]
            # if it's not NULL - convert it from char to int,
            # otherwise it means fully opaque color, as well as NULL alpha in ZPNG::Color
            color = color.dup
            color.alpha = color.alpha.ord
          end
        end
        return color

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
            if image.trns
              extend Mixins::RGB24_TRNS
            else
              extend Mixins::RGB24
            end
            return self[x]
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
          extend Mixins::RGBA32
          return self[x]
        when 64                         # RGBA 16-bit/sample
          return Color.new(*raw.unpack('n4'), :depth => 16 )
        else raise "COLOR_RGBA unexpected bpp #@bpp"
        end

      else
        raise "unexpected color mode #{image.hdr.color}"

      end # case img.hdr.color
    end

    def decoded_bytes
      @decoded_bytes ||=
        begin
          raw = @image.imagedata[@offset+1, size-1]
          if raw.size < size-1
            # handle broken images when data ends in the middle of scanline
            raw += "\x00" * (size-1-raw.size)
          end
          # TODO: check if converting raw to array would give any speedup

          # number of bytes per complete pixel, rounding up to one
          bpp1 = (@bpp/8.0).ceil

          case @filter

          when FILTER_NONE    # 0
            s = raw

          when FILTER_SUB     # 1
            s = "\x00" * (size-1)
            s[0,bpp1] = raw[0,bpp1] # TODO: optimize
            bpp1.upto(size-2) do |i|
              s.setbyte(i, raw.getbyte(i) + s.getbyte(i-bpp1))
            end

          when FILTER_UP      # 2
            s = "\x00" * (size-1)
            0.upto(size-2) do |i|
              s.setbyte(i, raw.getbyte(i) + prev_scanline_byte(i))
            end

          when FILTER_AVERAGE # 3
            s = "\x00" * (size-1)
            0.upto(bpp1-1) do |i|
              s.setbyte(i, raw.getbyte(i) + prev_scanline_byte(i)/2)
            end
            bpp1.upto(size-2) do |i|
              s.setbyte(i, raw.getbyte(i) + (s.getbyte(i-bpp1) + prev_scanline_byte(i))/2)
            end

          when FILTER_PAETH   # 4
            s = "\x00" * (size-1)
            0.upto(bpp1-1) do |i|
              s.setbyte(i, raw.getbyte(i) + prev_scanline_byte(i))
            end
            bpp1.upto(size-2) do |i|
              s.setbyte(i,
                raw.getbyte(i) +
                paeth_predictor(s.getbyte(i-bpp1), prev_scanline_byte(i), prev_scanline_byte(i-bpp1))
              )
            end

          else
            STDERR.puts "[!] #{self.class}: ##@idx: invalid filter #@filter, assuming FILTER_NONE".red
            s = raw
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

    def raw_data= data
      if data.size == size
        @image.imagedata[@offset, size] = data
      else
        raise Exception, "raw data size must be #{size}, got #{data.size}"
      end
    end

    # set raw byte data at specified offset
    # modifies @image, resets @decoded_bytes
    def raw_set offset, value
      @decoded_bytes = nil
      value = value.ord if value.is_a?(String)
      if offset == 0
        @filter = value # XXX possible bugs with Singleton Modules
      end
      @image.imagedata.setbyte(@offset+offset, value)
    end

    private

    def prev_scanline_byte x
      # defining instance methods gives 10-15% speed boost
      if image.interlaced?
        extend Mixins::Interlaced
      elsif @idx > 0
        extend Mixins::NotFirstLine
      else
        extend Mixins::FirstLine
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
      # [] is for preventing spare tail bytes that can break scanlines sequence
      if @decoded_bytes
        FILTER_NONE.chr + decoded_bytes[0,size-1]
      else
        # scanline was never decoded => export it as-is to save memory & CPU
        @image.imagedata[@offset, size]
      end
    end

    def each_pixel
      width.times do |i|
        yield self[i], i
      end
    end

    def pixels
      Pixels.new(self)
    end
  end
end
