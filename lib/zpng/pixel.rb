module ZPNG
  class Pixel < Struct.new(:r,:g,:b,:a)

    BLACK = Pixel.new(0,0,0,0)
    WHITE = Pixel.new(0xff,0xff,0xff,0)

    def white?
      r == 0xff && g == 0xff && b == 0xff
    end

    def black?
      r == 0 && g == 0 && b == 0
    end

    def to_s
      "%02X%02X%02X" % [r,g,b]
    end
  end
end
