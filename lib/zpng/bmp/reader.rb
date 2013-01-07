module ZPNG
  module BMP
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
        super(
          :width   => bmp_hdr.biWidth,
          :height  => bmp_hdr.biHeight.abs,
          :bpp     => bmp_hdr.biBitCount,
          :type    => 'BITMAPINFOHEADER',
          :crc     => :no_crc               # for CLI
        )
      end
      def inspect *args
        @bmp_hdr.inspect
      end
    end

    class Color < ZPNG::Color
      # BMP pixels are in perverted^w reverted order - BGR instead of RGB
      def initialize *a
        h = a.last.is_a?(Hash) ? a.pop : {}
        case a.size
        when 3,4
          # BGR, ABGR
          super *a.reverse, h
        else
          super
        end
      end
    end

    module Reader
      # http://en.wikipedia.org/wiki/BMP_file_format

      def _read_bmp io
        filesize, reserved1, reserved2, imagedata_offset = io.read(4+2+2+4).unpack('VvvV')
        # DIB Header immediately follows the Bitmap File Header
        hdr = BITMAPINFOHEADER.read(io)
        if hdr.biSize != BITMAPINFOHEADER::SIZE
          raise "dib_hdr_size #{hdr.biSize} unsupported, want #{BITMAPINFOHEADER::SIZE}"
        end

        @new_image = true
        @color_class = BMP::Color
        @chunks << BmpHdrPseudoChunk.new(hdr)

        # http://en.wikipedia.org/wiki/BMP_file_format#Pixel_storage
        row_size = ((hdr.biBitCount*self.width+31)/32)*4
        # XXX hidden data in non-significant tail bits/bytes

        io.seek(imagedata_offset)

        @scanlines = []
        self.height.times do |idx|
          data = io.read(row_size)
          # BMP scanlines layout is upside-down
          @scanlines.unshift ScanLine.new(self, height-idx-1,
                                          :decoded_bytes => data,
                                          :size => row_size
                                         )
        end
      end
    end # Reader
  end # BMP
end # ZPNG
