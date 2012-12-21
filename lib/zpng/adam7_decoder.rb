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

    # convert "flat" coords in scanline number & pos in scanline
    def convert_coords x,y
      # optimizing this into one switch/case statement gives
      # about 1-2% speed increase (ruby 1.9.3p286)

      if y%2 == 1
        # 7th pass: last height/2 full scanlines
        [x, y/2 + image.height*11/8]
      elsif x%2 == 1 && y%2 == 0
        # 6th pass
        [x/2, y/2 + image.height*7/8]
      elsif x%8 == 0 && y%8 == 0
        # 1st pass
        [x/8, y/8]
      elsif x%8 == 4 && y%8 == 0
        # 2nd pass
        [x/8, y/8 + image.height/8]
      elsif x%4 == 0 && y%8 == 4
        # 3rd pass
        [x/4, y/8 + image.height*2/8]
      elsif x%4 == 2 && y%4 == 0
        # 4th pass
        [x/4, y/4 + image.height*3/8]
      elsif x%2 == 0 && y%4 == 2
        # 5th pass
        [x/2, y/4 + image.height*5/8]
      else
        raise "invalid coords"
      end
    end
  end
end
