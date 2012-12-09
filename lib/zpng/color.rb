module ZPNG
  class Color < Struct.new(:r,:g,:b,:a)

    alias :alpha :a

    BLACK = Color.new(0,0,0,0xff)
    WHITE = Color.new(0xff,0xff,0xff,0xff)

    def white?
      r == 0xff && g == 0xff && b == 0xff
    end

    def black?
      r == 0 && g == 0 && b == 0
    end

    def transparent?
      a == 0
    end

    def to_grayscale
      (r+g+b)/3
    end

    def to_s
      "%02X%02X%02X" % [r,g,b]
    end
  end
end
