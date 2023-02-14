module ZPNG
  class Adam7Decoder
    attr_accessor :bpp
    attr_reader :scanlines_count

    # http://en.wikipedia.org/wiki/Adam7_algorithm#Passes
    def initialize width, height, bpp
      @bpp = bpp
      raise "Invalid BPP #{@bpp.inspect}" if @bpp.to_i == 0
      @widths = [
        [(width/8.0).ceil]     * (height/8.0).ceil,     # pass1
        [((width-4)/8.0).ceil] * (height/8.0).ceil,     # pass2
        [(width/4.0).ceil]     * ((height-4)/8.0).ceil, # pass3
        [((width-2)/4.0).ceil] * (height/4.0).ceil,     # pass4
        [(width/2.0).ceil]     * ((height-2)/4.0).ceil, # pass5
        [((width-1)/2.0).ceil] * (height/2.0).ceil,     # pass6
        [width]                * ((height-1)/2.0).ceil  # pass7
      ].map{ |x| x == [0] ? [] : x }
      @scanlines_count = 0
      # two leading zeroes added specially for convert_coords() code readability
      @pass_starts = [0,0] + @widths.map(&:size).map{ |x| @scanlines_count+=x }
      @widths.flatten! # yahoo! :))
    end

    # scanline width in pixels
    def scanline_width idx
      @widths[idx]
    end

    # scanline size in bytes, INCLUDING leading filter byte
    def scanline_size idx
      (scanline_width(idx) * bpp / 8.0).ceil + 1
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
        [x, y/2 + @pass_starts[7]]
      elsif x%2 == 1 && y%2 == 0
        # 6th pass
        [x/2, y/2 + @pass_starts[6]]
      elsif x%8 == 0 && y%8 == 0
        # 1st pass, starts at 0
        [x/8, y/8]
      elsif x%8 == 4 && y%8 == 0
        # 2nd pass
        [x/8, y/8 + @pass_starts[2]]
      elsif x%4 == 0 && y%8 == 4
        # 3rd pass
        [x/4, y/8 + @pass_starts[3]]
      elsif x%4 == 2 && y%4 == 0
        # 4th pass
        [x/4, y/4 + @pass_starts[4]]
      elsif x%2 == 0 && y%4 == 2
        # 5th pass
        [x/2, y/4 + @pass_starts[5]]
      else
        raise "invalid coords"
      end
    end

    # is the specified scanline is a first scanline in the pass?
    # When the image is interlaced, each pass of the interlace pattern is
    # treated as an independent image for filtering purposes
    def pass_start? idx
      @pass_starts.include?(idx)
    end
  end
end
