module ZPNG
  module BMP

    class BITMAPFILEHEADER < ReadableStruct.new 'VvvV', #a2VvvV',
      #:bfType,
      :bfSize,      # the size of the BMP file in bytes
      :bfReserved1,
      :bfReserved2,
      :bfOffBits    # imagedata offset

      def inspect
        "<" + super.partition(self.class.to_s.split('::').last)[1..-1].join
      end
    end

    class BITMAPINFOHEADER < ReadableStruct.new 'V3v2V6',
      :biSize,          # BITMAPINFOHEADER::SIZE
      :biWidth,
      :biHeight,
      :biPlanes,
      :biBitCount,
      :biCompression,
      :biSizeImage,
      :biXPelsPerMeter,
      :biYPelsPerMeter,
      :biClrUsed,
      :biClrImportant

      def inspect
        "<" + super.partition(self.class.to_s.split('::').last)[1..-1].join
      end
    end

    class BmpHdrPseudoChunk < Chunk::IHDR
      def initialize bmp_hdr
        @bmp_hdr = bmp_hdr
        h = {
          :width   => bmp_hdr.biWidth,
          :height  => bmp_hdr.biHeight.abs,
          :type    => 'BITMAPINFOHEADER',
          :crc     => :no_crc               # for CLI
        }
        if bmp_hdr.biBitCount == 8
          h[:color] = COLOR_INDEXED
          h[:depth] = 8
        else
          h[:bpp] = bmp_hdr.biBitCount
        end
        super(h)
        self.data = bmp_hdr.pack
      end
      def inspect *args
        @bmp_hdr.inspect
      end
      def method_missing mname, *args
        if @bmp_hdr.respond_to?(mname)
          @bmp_hdr.send(mname,*args)
        else
          super
        end
      end
    end

    class TypedBlock < Struct.new(:type, :size, :offset, :data)
      def inspect
        # string length of 16 is for alignment with BITMAP....HEADER chunks on
        # zpng CLI output
        "<%s size=%-5d (0x%-4x) offset=%-5d (0x%-4x)>" %
          [type, size, size, offset, offset]
      end
      def pack; data; end
    end

    class BmpPseudoChunk < Chunk
      def initialize struct
        @struct = struct
        type =
          if struct.respond_to?(:type)
            struct.type
          else
            struct.class.to_s.split('::').last
          end

        super(
          #:size    => struct.class.const_get('SIZE'),
          :type    => type,
          :data    => struct.pack,
          :crc     => :no_crc               # for CLI
        )
      end
      def inspect *args
        @struct.inspect
      end
      def method_missing mname, *args
        if @struct.respond_to?(mname)
          @struct.send(mname,*args)
        else
          super
        end
      end
    end

    class BmpPaletteChunk < Chunk::PLTE
      def initialize data
        super(
          :crc  => :no_crc,
          :data => data,
          :type => 'PALETTE'
        )
      end

      def [] idx
        rgbx = @data[idx*4,4]
        rgbx && Color.new(*rgbx.unpack('C4'))
      end

      def []= idx, color
        @data ||= ''
        @data[idx*4,4] = [color.r, color.g, color.b, color.a].pack('C4')
      end

      def ncolors
        @data.to_s.size/4
      end

      def inspect *args
        "<%s ncolors=%d>" % ["PALETTE", size/4]
      end
    end

    class Color < ZPNG::Color
      # BMP pixels are in perverted^w reverted order - BGR instead of RGB
      def initialize *a
        h = a.last.is_a?(Hash) ? a.pop : {}
        case a.size
        when 3
          # BGR
          super *a.reverse, h
        when 4
          # ABGR
          super a[2], a[1], a[0], a[3], h
        else
          super
        end
      end
    end

    module ImageMixin
      def imagedata
        @imagedata ||= @scanlines.sort_by(&:offset).map(&:decoded_bytes).join
      end
    end

    module Reader
      # http://en.wikipedia.org/wiki/BMP_file_format

      def _read_bmp io
        fhdr = BITMAPFILEHEADER.read(io)
        # DIB Header immediately follows the Bitmap File Header
        ihdr = BITMAPINFOHEADER.read(io)
        if ihdr.biSize != BITMAPINFOHEADER::SIZE
          raise "dib_hdr_size #{ihdr.biSize} unsupported, want #{BITMAPINFOHEADER::SIZE}"
        end

        @new_image = true
        @color_class = BMP::Color
        @format = :bmp
        @chunks << BmpPseudoChunk.new(fhdr)
        @chunks << BmpHdrPseudoChunk.new(ihdr)

        # http://en.wikipedia.org/wiki/BMP_file_format#Pixel_storage
        row_size = ((ihdr.biBitCount*self.width+31)/32)*4

        gap1_size = fhdr.bfOffBits - io.tell

        STDERR.puts "[?] negative gap1=#{gap1_size}".red if gap1_size < 0

        if ihdr.biBitCount == 8 && gap1_size >= 1024
          # palette for 256-color BMP
          data = io.read 1024
          @chunks << BmpPaletteChunk.new(data)
          gap1_size -= 1024
        end

        if gap1_size != 0
          @chunks << BmpPseudoChunk.new(
            TypedBlock.new("GAP1", gap1_size, io.tell, io.read(gap1_size))
          )
          #io.seek(fhdr.bfOffBits)
        end

        pos0 = io.tell
        @scanlines = []
        self.height.times do |idx|
          offset = io.tell - fhdr.bfOffBits
          data = io.read(row_size)
          # BMP scanlines layout is upside-down
          @scanlines.unshift ScanLine.new(self, self.height-idx-1,
                                          :decoded_bytes => data,
                                          :size   => row_size,
                                          :offset => offset
                                         )
        end

        @chunks << BmpPseudoChunk.new(
            TypedBlock.new("IMAGEDATA", io.tell - pos0, pos0, '')
        )

        unless io.eof?
          @chunks << BmpPseudoChunk.new(
            TypedBlock.new("GAP2", io.size - io.tell, io.tell, '')
          )
        end

        extend ImageMixin
      end
    end # Reader
  end # BMP
end # ZPNG
