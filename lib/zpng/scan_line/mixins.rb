module ZPNG
  class ScanLine
    module Mixins

      # scanline decoding

      module Interlaced
        def prev_scanline_byte x
          # When the image is interlaced, each pass of the interlace pattern is
          # treated as an independent image for filtering purposes
          image.adam7.pass_start?(@idx) ? 0 : image.scanlines[@idx-1].decoded_bytes.getbyte(x)
        end
      end

      module NotFirstLine
        def prev_scanline_byte x
          image.scanlines[@idx-1].decoded_bytes.getbyte(x)
        end
      end

      module FirstLine
        def prev_scanline_byte x
          0
        end
      end

      # pixel access

      # RGB  8 bits per sample = 24bpp
      module RGB24
        def [] x
          t = x*3
          # color_class is for (limited) BMP support
          image.color_class.new(
            decoded_bytes.getbyte(t),
            decoded_bytes.getbyte(t+1),
            decoded_bytes.getbyte(t+2)
          )
        end
      end

      # if image has tRNS chunk - 10% slower than RGB24
      module RGB24_TRNS
        def [] x
          t = x*3
          # color_class is for (limited) BMP support
          color = image.color_class.new(
            decoded_bytes.getbyte(t),
            decoded_bytes.getbyte(t+1),
            decoded_bytes.getbyte(t+2)
          )
          color.alpha = image._alpha_color(color)
          color
        end
      end

      # RGBA 8 bits per sample = 32bpp
      module RGBA32
        def [] x
          # substring  => 1.50s on 270_000 pixels
          # getbyte(s) => 1.25s on 270_000 pixels
          t = x*4
          image.color_class.new(
            decoded_bytes.getbyte(t),
            decoded_bytes.getbyte(t+1),
            decoded_bytes.getbyte(t+2),
            decoded_bytes.getbyte(t+3)
          )
        end
      end

    end # Mixins
  end # ScanLine
end # ZPNG
