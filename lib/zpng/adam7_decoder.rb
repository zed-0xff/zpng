module ZPNG
  class Adam7Decoder
    attr_accessor :image

    def initialize image
      @image = image
    end

    def scanlines_count
      (15*image.height/8.0).ceil
    end

    WIDTHS = [1,1,2,2,2,4,4,4,4,4,4,8,8,8,8]

    # scanline width in pixels
    def scanline_width idx
      #image.width/8*(2**(idx/2))
      WIDTHS[idx*8/image.height]*(image.width/8)
    end

    # scanline size in bytes, INCLUDING leading filter byte
    def scanline_size idx
      (scanline_width(idx) * image.bpp / 8.0).ceil + 1
    end

    # scanline offset in imagedata
    def scanline_offset idx
      #TODO: optimize
      (0...idx).map{ |x| scanline_size(x) }.inject(&:+) || 0
    end
  end
end
